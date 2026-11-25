param([string]$Report = (Join-Path $env:TEMP 'prompty-filesystem-picker-report.txt'))
$ErrorActionPreference = 'Stop'
Remove-Item $Report -Force -ErrorAction SilentlyContinue
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PickerNativeProbe {
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
  try { var a=new Input[text.Length*2]; for(int j=0;j<text.Length;j++){ var c=text[j]; a[j*2]=new Input{Type=1,Down=1,Repeat=1,VK=(ushort)Char.ToUpper(c),Char=c}; a[j*2+1]=a[j*2]; a[j*2+1].Down=0; } uint n; if(!WriteConsoleInput(h,a,(uint)a.Length,out n)||n!=a.Length) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); } finally { CloseHandle(h); }
 }
}
"@
$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
$fixture = Join-Path $env:TEMP ("picker-native-" + [guid]::NewGuid())
New-Item -ItemType Directory $fixture | Out-Null
Set-Content (Join-Path $fixture 'answer.txt') 'unchanged'
Set-Content (Join-Path $fixture '.hidden') 'hidden'
New-Item -ItemType Directory (Join-Path $fixture 'child') | Out-Null
cmd /c mklink /J (Join-Path $fixture 'linked') (Join-Path $fixture 'child') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not create junction fixture' }
cmd /c mklink /J (Join-Path $fixture 'child\loop') $fixture | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not create cycle fixture' }
$results = @()
function Invoke-Picker([string]$Scenario, [string]$Base, [string]$Keys, [string]$Expected) {
 $file = Join-Path $env:TEMP ("picker-native-" + [guid]::NewGuid() + '.txt')
 $line = "Set-Location '$root'; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.ready');`$childWait++){ Start-Sleep -Milliseconds 50 }; if(!(Test-Path '$file.ready')){ exit 3 }; & '$dart' run test/filesystem_picker_native_app.dart $Scenario '$Base' > '$file'; Set-Content '$file.done' done; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.release');`$childWait++){ Start-Sleep -Milliseconds 50 }"
 $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
 $p = $null
 try {
  $p=Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
  [void][PickerNativeProbe]::FreeConsole()
  $attached=$false
  for($n=0;$n -lt 100 -and !$attached;$n++){ $attached=[PickerNativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
  if(!$attached){throw 'AttachConsole failed'}
  $before=[PickerNativeProbe]::State()
  Set-Content -Path "$file.ready" -Value ready
  # Bounded-wait for interaction readiness: acquiring the console moves the
  # observed state away from the pre-launch baseline, which distinguishes
  # compilation time from prompt responsiveness.
  $ready=$false
  for($n=0;$n -lt 600 -and !$ready;$n++){
   if(Test-Path "$file.done"){break}
   if([PickerNativeProbe]::State() -ne $before){$ready=$true}else{Start-Sleep -Milliseconds 100}
  }
  if(!$ready -and !(Test-Path "$file.done")){throw "$Scenario console state never left the pre-launch baseline within 60 seconds"}
  [PickerNativeProbe]::Text($Keys)
  for($n=0;$n -lt 150 -and !(Test-Path "$file.done");$n++){Start-Sleep -Milliseconds 100}
  if (!(Test-Path "$file.done")) { throw "$Scenario process did not exit" }
  $actual=(Get-Content $file -Raw).Trim()
  $after=''; for($n=0;$n -lt 100;$n++){ $after=[PickerNativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
  if($actual -ne $Expected){throw "$Scenario unexpected result: $actual; expected $Expected"}
  if($before -ne $after){throw "$Scenario console state changed: $before -> $after"}
  $script:results += "$Scenario PASS result=$actual state=$before -> $after"
 } finally {
  Set-Content -Path "$file.release" -Value release -ErrorAction SilentlyContinue
  [void][PickerNativeProbe]::FreeConsole()
  if($p -and !$p.HasExited){ [void]$p.WaitForExit(1000) }; if($p -and !$p.HasExited){ & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null; if(!$p.WaitForExit(2000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue} }
  Remove-Item $file,"$file.release","$file.ready","$file.done" -Force -ErrorAction SilentlyContinue
 }
}
try {
 Invoke-Picker 'file-rich' $fixture "refresh`rhidden`rhidden`rchoose 1`r`r" (Join-Path $fixture 'answer.txt')
 Invoke-Picker 'directory-linear' (Join-Path $fixture 'child') "parent`rrefresh`rchoose`r`r" $fixture
 Invoke-Picker 'directory-rich' $fixture "open 3 links`rchoose`r`r" (Join-Path $fixture 'linked')
 Invoke-Picker 'directory-linear' $fixture "open 3 links`rchoose`r`r" (Join-Path $fixture 'linked')
 # A cycle is covered by opening the junction after entering it: its target is an ancestor.
 Invoke-Picker 'directory-rich' (Join-Path $fixture 'linked') "open 1 links`rchoose`r`r" (Join-Path $fixture 'linked')
 Set-Content $Report ($results -join [Environment]::NewLine)
 Get-Content $Report
} catch { Set-Content $Report "filesystem picker FAIL $_"; throw }
finally { Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue }
