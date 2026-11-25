param([Parameter(Mandatory=$true)][string]$Report, [ValidateSet('rich','linear')][string]$Scenario = 'rich')
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class FeedbackConsoleProbe {
 [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X; public short Y; }
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public short Left, Top, Right, Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct Info { public Coord Size, Cursor; public short Attributes; public Rect Window; public Coord Maximum; }
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint id);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h,out uint mode);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfo(IntPtr h,out Info info);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacter(IntPtr h,StringBuilder text,uint length,Coord origin,out uint read);
 public static string Mode(string file) { var h=CreateFile(file,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); try { uint m; if(!GetConsoleMode(h,out m)) throw new Exception("mode " + Marshal.GetLastWin32Error()); return m.ToString(); } finally { CloseHandle(h); } }
 public static int Width() { var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); try { Info i; if(!GetConsoleScreenBufferInfo(h,out i)) throw new Exception("info"); return i.Size.X; } finally { CloseHandle(h); } }
 public static string Screen() { var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); try { Info i; if(!GetConsoleScreenBufferInfo(h,out i)) throw new Exception("info"); var text=new StringBuilder(i.Size.X*i.Size.Y); uint n; if(!ReadConsoleOutputCharacter(h,text,(uint)(i.Size.X*i.Size.Y),new Coord(),out n)) throw new Exception("read " + Marshal.GetLastWin32Error()); return text.ToString(); } finally { CloseHandle(h); } }
}
"@
$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
$done = Join-Path $env:TEMP ("feedback-done-" + [guid]::NewGuid())
$line = @"
Set-Location '$root'
`$host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(30,25)
`$host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(30,300)
Start-Sleep -Seconds 4
& '$dart' run test/feedback_native_app.dart wait $Scenario
Set-Content '$done' done
Start-Sleep -Seconds 5
"@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$p = $null
try {
 $p = Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 [void][FeedbackConsoleProbe]::FreeConsole()
 $attached = $false
 for($n=0;$n -lt 100 -and !$attached;$n++) { $attached=[FeedbackConsoleProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw 'AttachConsole failed'}
 $before = [FeedbackConsoleProbe]::Mode('CONIN$')
 # Bounded-wait for the application's observable final output line instead
 # of assuming a fixed delay covered compilation and painting.
 $screen=''
 $painted=$false
 for($n=0;$n -lt 600 -and !$painted;$n++){
  $screen=[FeedbackConsoleProbe]::Screen()
  if($screen.Contains('application result')){$painted=$true}else{Start-Sleep -Milliseconds 100}
 }
 if(!$painted){throw "feedback output did not paint within 60 seconds"}
 $during = [FeedbackConsoleProbe]::Mode('CONIN$')
 if ([FeedbackConsoleProbe]::Width() -ne 30) {throw "console was not narrow"}
 $screen = [FeedbackConsoleProbe]::Screen() -replace '\s+', ' '
 foreach ($part in @('Warning: literal\u001b[31m', 'failed:', 'network', 'unavailable', 'Connection: skipped', 'Summary:', 'build: completed', 'test: failed:', 'application result')) {
   if (!$screen.Contains($part)) {throw "missing [$part] from screen: $screen"}
 }
 if ($before -ne $during) {throw "input mode changed: $before -> $during"}
 Set-Content $Report "feedback native $Scenario narrow console PASS input mode $before -> $during"
} catch { Set-Content $Report "feedback native FAIL $_"; throw } finally {
 [void][FeedbackConsoleProbe]::FreeConsole()
 if($p -and !$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}
 Remove-Item $done -Force -ErrorAction SilentlyContinue
}

