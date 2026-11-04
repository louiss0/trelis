param([string]$Scenario = 'repeat', [string]$Report = (Join-Path $env:TEMP 'prompty-probe-report.txt'))
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
  try { var a=new Input[2]; a[0]=new Input{Type=1,Down=1,Repeat=1,VK=vk,Char=c,State=state}; a[1]=a[0]; a[1].Down=0; uint n; if(!WriteConsoleInput(h,a,2,out n)||n!=2) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); }
  finally { CloseHandle(h); }
 }
}
"@
$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
$file = Join-Path $env:TEMP ("editable-probe-" + [guid]::NewGuid() + '.txt')
$redirect = if ($Scenario -eq 'redirected') { "2> '$file.stderr'" } else { '' }
$line = "Set-Location '$root'; Start-Sleep -Seconds 3; & '$dart' run test/text_input_native_app.dart $Scenario $redirect > '$file'; Set-Content '$file.done' done; Start-Sleep -Seconds 20"
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
 Start-Sleep -Seconds 7
 $during=[NativeProbe]::State()
 $parts=$during.Split(':')
 if (([int]$parts[1] -band 4) -eq 0) {throw "VT output not enabled: $during"}
 switch ($Scenario) {
  'repeat' { [NativeProbe]::Text("`r`r") }
  'error' { [NativeProbe]::Text("`r`r") }
  'eof' { [NativeProbe]::Key([char]26,90,8) }
  'escape' { [NativeProbe]::Key([char]27,27,0) }
  'concurrent' { [NativeProbe]::Text("`r") }
  'rich' { [NativeProbe]::Text("`r") }
  'redirected' { [NativeProbe]::Text("`r") }
  'stdout' { [NativeProbe]::Text("`r") }
  'paste' { [NativeProbe]::Text("$([char]27)[200~/cancel$([char]27)[201~`r") }
  'unicode' { [NativeProbe]::Text("$([char]::ConvertFromUtf32(0x1f600))`r") }
  'interrupt' { [NativeProbe]::Key([char]3,67,8) }
  default { throw "Unknown scenario $Scenario" }
 }
 for($n=0;$n -lt 100;$n++){if((Test-Path $file) -and (Get-Item $file).Length -gt 0){break}; Start-Sleep -Milliseconds 100}

 for($n=0;$n -lt 100 -and !(Test-Path "$file.done");$n++){Start-Sleep -Milliseconds 100}
 if (!(Test-Path "$file.done")) { throw "probe process did not exit" }
 $actual=(Get-Content $file -Raw).Trim()
 $after=''; for($n=0;$n -lt 100;$n++){ $after=[NativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
 if ($Scenario -eq 'stdout') {
  if ($actual.Contains([char]27) -or !$actual.Contains('Name')) { throw 'unstable stdout transcript' }
  $actual = ($actual -split "`r?`n")[-1]
 }
 $expected = switch ($Scenario) { 'repeat' { 'alpha,alpha' } 'error' { 'alpha' } 'eof' { 'eof' } 'escape' { 'cancel' } 'concurrent' { 'busy,alpha' } 'rich' { 'alpha' } 'redirected' { 'alpha' } 'stdout' { 'alpha' } 'paste' { '/cancel' } 'unicode' { '1f600' } 'interrupt' { 'interrupt' } }
 if($actual -ne $expected){throw "unexpected result: $actual"}
 if($Scenario -eq 'redirected') {
  $transcript = Get-Content "$file.stderr" -Raw
  if ($transcript.Contains([char]27) -or !$transcript.Contains('Name')) { throw 'unstable redirected output' }
 }
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content $Report "text input $Scenario PASS result=$actual state=$before -> $during -> $after"
} catch { Set-Content $Report "text input $Scenario FAIL $_"; throw }
finally { [void][NativeProbe]::FreeConsole(); if($p -and !$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}; Remove-Item $file,"$file.done","$file.stderr" -Force -ErrorAction SilentlyContinue }

