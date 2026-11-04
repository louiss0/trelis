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
$line = "Set-Location '$root'; Start-Sleep -Seconds 4; & '$dart' run bin/terminal_probe.dart --twice > '$file'; Start-Sleep -Seconds 30"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$p = $null
try {
 $p = Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 [void][NativeProbe]::FreeConsole()
 $attached = $false
 for ($n=0; $n -lt 100 -and !$attached; $n++) { $attached=[NativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw "AttachConsole failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"}
 $before=[NativeProbe]::State()
 Start-Sleep -Seconds 7
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
  Start-Sleep -Seconds 2
 }
 for($n=0; $n -lt 100; $n++){ if((Test-Path $file) -and ((Get-Content $file -ErrorAction SilentlyContinue | Measure-Object -Line).Lines -ge 2)){break}; Start-Sleep -Milliseconds 100 }
 $actual=@(Get-Content $file)
 $after=[NativeProbe]::State()
 if($actual.Count -ne 2 -or $actual[0] -ne $expected -or $actual[1] -ne $expected){ throw "unexpected results: $($actual -join ',')" }
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content -Path $Report -Value "$Scenario PASS results=$($actual -join ',') state=$before -> $after"
} catch {
 Set-Content -Path $Report -Value "$Scenario FAIL $_"
 throw
} finally {
 [void][NativeProbe]::FreeConsole()
 if($p -and !$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}
 Remove-Item $file -Force -ErrorAction SilentlyContinue
}
