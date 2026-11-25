param([string]$Scenario = 'rich', [string]$Report = (Join-Path $env:TEMP 'prompty-probe-report.txt'))
$ErrorActionPreference = 'Stop'
Remove-Item $Report -Force -ErrorAction SilentlyContinue
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeProbe {
 [StructLayout(LayoutKind.Explicit, Size=20, CharSet=CharSet.Unicode)] public struct Input {
  [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public int Down;
  [FieldOffset(8)] public ushort Repeat; [FieldOffset(10)] public ushort VK;
  [FieldOffset(14)] public char Char; [FieldOffset(16)] public uint State;
 }
 [StructLayout(LayoutKind.Sequential)] public struct Cursor { public uint Size; public int Visible; }
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint id);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h,out uint mode);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleCursorInfo(IntPtr h,out Cursor info);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInput(IntPtr h,Input[] records,uint length,out uint written);
 public static string State() {
  var i=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  var o=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { uint im,om; Cursor c; if(!GetConsoleMode(i,out im)||!GetConsoleMode(o,out om)||!GetConsoleCursorInfo(o,out c)) throw new Exception("console state error " + Marshal.GetLastWin32Error()); return im+":"+om+":"+c.Size+":"+c.Visible; }
  finally { CloseHandle(i); CloseHandle(o); }
 }
 public static void Text(string text) {
  var h=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { var a=new Input[text.Length*2]; for(int j=0;j<text.Length;j++){ var c=text[j]; a[j*2]=new Input{Type=1,Down=1,Repeat=1,VK=(ushort)(c == '~' ? 192 : Char.ToUpper(c)),Char=c}; a[j*2+1]=a[j*2]; a[j*2+1].Down=0; } uint n; if(!WriteConsoleInput(h,a,(uint)a.Length,out n)||n!=a.Length) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); } finally { CloseHandle(h); }
 }
 public static void Key(char c, ushort vk, uint state) {
  var h=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { var a=new Input[3]; a[0]=new Input{Type=1,Down=1,Repeat=1,VK=vk,Char=c,State=state}; a[1]=a[0]; a[2]=a[0]; a[2].Down=0; uint n; if(!WriteConsoleInput(h,a,3,out n)||n!=3) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); }
  finally { CloseHandle(h); }
 }
}
"@
$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
$file = Join-Path $env:TEMP ("editable-probe-" + [guid]::NewGuid() + '.txt')
$line = "Set-Location '$root'; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.ready');`$childWait++){ Start-Sleep -Milliseconds 50 }; if(!(Test-Path '$file.ready')){ exit 3 }; & '$dart' run test/key_capture_native_app.dart $Scenario > '$file'; Set-Content '$file.done' done; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.release');`$childWait++){ Start-Sleep -Milliseconds 50 }"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$p = $null
try {
 $p=Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 [void][NativeProbe]::FreeConsole()
 $attached=$false
 for($n=0;$n -lt 100 -and !$attached;$n++){ $attached=[NativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw 'AttachConsole failed'}
 # The Dart launcher itself enables VT output; preserve its normal console baseline.
 $before=[NativeProbe]::State()
 Set-Content -Path "$file.ready" -Value ready
 # Bounded-wait for interaction readiness: the application acquiring the
 # console flips the observed state away from the pre-launch baseline with
 # VT output enabled, which distinguishes compilation time from prompt
 # responsiveness instead of assuming a fixed startup delay was enough.
 $during=''
 $parts=@()
 $ready=$false
 for($n=0;$n -lt 600 -and !$ready;$n++){
  if(Test-Path "$file.done"){break}
  $during=[NativeProbe]::State()
  $parts=$during.Split(':')
  if (([int]$parts[1] -band 4) -ne 0 -and $during -ne $before) {$ready=$true} else {Start-Sleep -Milliseconds 100}
 }
 if((Test-Path "$file.done") -and !$ready){
  # The application finished before any interaction: readiness is moot.
  $during=[NativeProbe]::State()
  $parts=$during.Split(':')
 } elseif(!$ready){
  $during=[NativeProbe]::State()
  $parts=$during.Split(':')
  if (([int]$parts[1] -band 4) -eq 0) {throw "VT output not enabled within 60 seconds: $during"}
  if ($during -eq $before) {throw "console state never left the pre-launch baseline within 60 seconds: $during"}
 }
 if ($Scenario -eq "cancel") {
  [NativeProbe]::Key([char]27, 0x1b, 0)
 } elseif ($Scenario -eq "interrupt") {
  [NativeProbe]::Key([char]3, 0x43, 8)
 } elseif ($Scenario -eq "linear") {
  [NativeProbe]::Text("Ctrl,B`r")
 } else {
  # Rich: Down selects Ctrl in the modifier cell, Tab focuses the key cell, two Downs select B, Enter submits.
  # Console input records are an ordered queue processed in order, so the
  # navigation needs no delays; the final result assertion proves the order.
  [NativeProbe]::Key([char]0, 0x28, 0)
  [NativeProbe]::Key([char]9, 0x09, 0)
  [NativeProbe]::Key([char]0, 0x28, 0)
  [NativeProbe]::Key([char]0, 0x28, 0)
  [NativeProbe]::Key([char]13, 0x0d, 0)
 }

 for($n=0;$n -lt 100;$n++){if((Test-Path $file) -and (Get-Item $file).Length -gt 0){break}; Start-Sleep -Milliseconds 100}

 for($n=0;$n -lt 100 -and !(Test-Path "$file.done");$n++){Start-Sleep -Milliseconds 100}
 if (!(Test-Path "$file.done")) { throw "probe process did not exit" }
 $actual=(Get-Content $file -Raw).Trim()
 $after=''; for($n=0;$n -lt 100;$n++){ $after=[NativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
 $expected = switch ($Scenario) { 'cancel' { 'Cancelled<List<String>>' } 'interrupt' { 'Interrupted<List<String>>' } default { 'Ctrl,B' } }
 if($actual -ne $expected){throw "unexpected result: $actual"}
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content $Report "key capture PASS result=$actual state=$before -> $during -> $after"
} catch { Set-Content $Report "key capture FAIL $_"; throw }
finally {
 Set-Content -Path "$file.release" -Value release -ErrorAction SilentlyContinue; [void][NativeProbe]::FreeConsole(); if($p -and !$p.HasExited){ [void]$p.WaitForExit(1000) }; if($p -and !$p.HasExited){ & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null; if(!$p.WaitForExit(2000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue} }; Remove-Item $file,"$file.release","$file.ready","$file.done","$file.stderr" -Force -ErrorAction SilentlyContinue }
