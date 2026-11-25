param([string]$Scenario = 'submit', [string]$Report = (Join-Path $env:TEMP 'prompty-probe-report.txt'))
$ErrorActionPreference = 'Stop'
Remove-Item $Report -Force -ErrorAction SilentlyContinue
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeProbe {
 [StructLayout(LayoutKind.Explicit, Size=20)] public struct Input {
  [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public int Down;
  [FieldOffset(8)] public ushort Repeat; [FieldOffset(10)] public ushort VK;
  [FieldOffset(14)] public char Char; [FieldOffset(16)] public uint State;
 }
 [StructLayout(LayoutKind.Sequential)] public struct Cursor { public uint Size; public int Visible; }
 [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X; public short Y; }
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public short Left; public short Top; public short Right; public short Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct BufferInfo { public Coord Size; public Coord Position; public ushort Attributes; public Rect Window; public Coord Maximum; }
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint id);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h,out uint mode);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleCursorInfo(IntPtr h,out Cursor info);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfo(IntPtr h,out BufferInfo info);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacter(IntPtr h,[Out] ushort[] text,uint length,Coord position,out uint read);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInput(IntPtr h,Input[] records,uint length,out uint written);
 public static string State() {
  var i=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  var o=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { uint im,om; Cursor c; if(!GetConsoleMode(i,out im)||!GetConsoleMode(o,out om)||!GetConsoleCursorInfo(o,out c)) throw new Exception("console state error " + Marshal.GetLastWin32Error()); return im+":"+om+":"+c.Size+":"+c.Visible; }
  finally { CloseHandle(i); CloseHandle(o); }
 }
 public static string ScreenText() {
  var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try {
   BufferInfo info; if(!GetConsoleScreenBufferInfo(h,out info)) throw new Exception("screen state error");
   var text=new ushort[info.Size.X*(info.Window.Bottom-info.Window.Top+1)]; uint read;
   if(!ReadConsoleOutputCharacter(h,text,(uint)text.Length,new Coord{X=0,Y=info.Window.Top},out read)) throw new Exception("screen read error");
   return new string(Array.ConvertAll(text,c=>(char)c),0,(int)read);
  } finally { CloseHandle(h); }
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
$file = Join-Path $env:TEMP ("prompty-probe-" + [guid]::NewGuid() + '.txt')
if($Scenario -eq 'stream-eof') {
 $line = @'
Set-Location '__ROOT__'
for($childWait=0;$childWait -lt 600 -and !(Test-Path '__FILE__.ready');$childWait++){ Start-Sleep -Milliseconds 50 }
if(!(Test-Path '__FILE__.ready')){ exit 3 }
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = '__DART__'
$info.Arguments = 'run bin/terminal_probe.dart --stream-stdin'
$info.UseShellExecute = $false
$info.RedirectStandardInput = $true
$info.RedirectStandardOutput = $true
$child = [System.Diagnostics.Process]::Start($info)
$child.StandardInput.Write('partial')
$child.StandardInput.Close()
$result = $child.StandardOutput.ReadToEnd()
$child.WaitForExit()
Set-Content -Path '__FILE__' -Value $result.TrimEnd()
for($childWait=0;$childWait -lt 600 -and !(Test-Path '__FILE__.release');$childWait++){ Start-Sleep -Milliseconds 50 }
'@.Replace('__ROOT__',$root).Replace('__DART__',$dart).Replace('__FILE__',$file)
} else {
 $line = "Set-Location '$root'; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.ready');`$childWait++){ Start-Sleep -Milliseconds 50 }; if(!(Test-Path '$file.ready')){ exit 3 }; & '$dart' run bin/terminal_probe.dart --twice --pause-between > '$file'; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.release');`$childWait++){ Start-Sleep -Milliseconds 50 }"
}
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$p = $null
try {
 $p = Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 [void][NativeProbe]::FreeConsole()
 $attached = $false
 for ($n=0; $n -lt 100 -and !$attached; $n++) { $attached=[NativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"}
 $before=[NativeProbe]::State()
 # The child performs no compilation or process launch until attachment and
 # baseline capture are complete; this handshake replaces fixed startup waits.
 Set-Content -Path "$file.ready" -Value ready
 if($Scenario -eq 'stream-eof') {
  for($n=0; $n -lt 150; $n++) { if((Test-Path $file) -and (Get-Item $file).Length -gt 0) { break }; Start-Sleep -Milliseconds 100 }
  $actual=@(Get-Content $file)
  # Bounded-wait for the observable console restoration rather than
  # assuming a fixed delay was enough.
  $after=''
  for($n=0;$n -lt 100;$n++){ $after=[NativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
  if($actual.Count -ne 1 -or $actual[0] -ne 'eof') { throw "unexpected EOF results: $($actual -join ',')" }
  if($before -ne $after) { throw "console state changed: $before -> $after" }
  Set-Content -Path $Report -Value "stream-eof PASS result=$($actual[0]) state=$before -> $after"
  return
 }
 # Bounded-wait for interaction readiness: the probe acquiring the console
 # moves the observed state away from the pre-launch baseline, which
 # distinguishes compilation time from prompt responsiveness.
 $ready=$false
 for($n=0;$n -lt 600 -and !$ready;$n++){
  if([NativeProbe]::State() -ne $before){$ready=$true}else{Start-Sleep -Milliseconds 100}
 }
 if(!$ready){throw "console state never left the pre-launch baseline within 60 seconds"}
 $openingPaint=$false
 for($n=0;$n -lt 150 -and !$openingPaint;$n++){
  if([NativeProbe]::ScreenText().Contains('probe 1>')){$openingPaint=$true}else{Start-Sleep -Milliseconds 100}
 }
 if(!$openingPaint){throw 'first probe prompt did not paint within 15 seconds'}
 switch ($Scenario) {
  'submit' { $char=[char]13; $vk=13; $state=0; $expected='submit:ok' }
  'escape' { $char=[char]27; $vk=27; $state=0; $expected='cancel' }
  'ctrlc' { $char=[char]3; $vk=67; $state=8; $expected='interrupt' }
  'eof' { $char=[char]26; $vk=90; $state=8; $expected='eof' }
  'error' { $char=[char]102; $vk=70; $state=0; $expected='error' }
  default { throw 'Unknown scenario' }
 }
 for($session=0; $session -lt 2; $session++) {
  if($Scenario -eq 'submit') { [NativeProbe]::Key([char]111,79,0); [NativeProbe]::Key([char]107,75,0) }
  if($Scenario -eq 'error') { foreach($c in 'abcde'.ToCharArray()) { [NativeProbe]::Key($c,[uint16][char]::ToUpper($c),0) } }
  [NativeProbe]::Key($char,$vk,$state)
  if($session -eq 0) {
   $middle = $null
   for($n=0; $n -lt 100; $n++) {
    Start-Sleep -Milliseconds 100
    $stateNow=[NativeProbe]::State()
    if($stateNow -eq $before) { $middle=$stateNow; break }
   }
   if(!$middle) { throw "first session did not restore console before next session" }
   $continuation=$false
   for($n=0;$n -lt 150 -and !$continuation;$n++){
    if([NativeProbe]::ScreenText().Contains('Press Enter for the next session.')){$continuation=$true}else{Start-Sleep -Milliseconds 100}
   }
   if(!$continuation){throw 'continuation prompt did not paint within 15 seconds'}
   [NativeProbe]::Key([char]13,13,0)
   # Bounded-wait for the second session to observably reacquire the
   # console and paint before its scenario keys are injected.
   $reacquired=$false
   for($n=0;$n -lt 150 -and !$reacquired;$n++){
    Start-Sleep -Milliseconds 100
    if([NativeProbe]::State() -ne $before -and [NativeProbe]::ScreenText().Contains('probe 2>')){$reacquired=$true}
   }
   if(!$reacquired){throw "second session did not reacquire the console and paint its prompt"}
  }
 }
 for($n=0; $n -lt 100; $n++){ if((Test-Path $file) -and ((Get-Content $file -ErrorAction SilentlyContinue | Measure-Object -Line).Lines -ge 2)){break}; Start-Sleep -Milliseconds 100 }
 $actual=@(Get-Content $file)
 $after=[NativeProbe]::State()
 if($actual.Count -ne 2 -or $actual[0] -ne $expected -or $actual[1] -ne $expected){ throw "unexpected results: $($actual -join ',')" }
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content -Path $Report -Value "$Scenario PASS results=$($actual -join ',') state=$before -> $middle -> $after"
} catch {
 Set-Content -Path $Report -Value "$Scenario FAIL $_"
 throw
} finally {
 Set-Content -Path "$file.release" -Value release -ErrorAction SilentlyContinue
 [void][NativeProbe]::FreeConsole()
 if($p -and !$p.HasExited){ [void]$p.WaitForExit(1000) }
 if($p -and !$p.HasExited){
  & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null
  if(!$p.WaitForExit(2000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}
 }
 Remove-Item $file,"$file.ready","$file.release" -Force -ErrorAction SilentlyContinue
}
