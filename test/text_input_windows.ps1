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
 public static string EditorState() {
  var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try {
   BufferInfo info; if(!GetConsoleScreenBufferInfo(h,out info)) throw new Exception("buffer state error " + Marshal.GetLastWin32Error());
   var text=new ushort[info.Size.X]; uint read;
   if(!ReadConsoleOutputCharacter(h,text,(uint)info.Size.X,new Coord{X=0,Y=info.Position.Y},out read)) throw new Exception("buffer read error " + Marshal.GetLastWin32Error());
   return info.Position.X+":"+info.Position.Y+":"+new string(Array.ConvertAll(text,c=>(char)c),0,(int)read).TrimEnd();
  } finally { CloseHandle(h); }
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
$term = if ($Scenario -like 'dumb-*') { "`$env:TERM='dumb';" } else { "" }
$line = "$term Set-Location '$root'; while (!(Test-Path '$file.ready')) { Start-Sleep -Milliseconds 50 }; & '$dart' run test/text_input_native_app.dart $Scenario $redirect > '$file'; Set-Content '$file.done' done; Start-Sleep -Seconds 20"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$p = $null
try {
 $p=Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 # Let Windows Terminal finish console delegation before attaching the probe.
 Start-Sleep -Seconds 3
 [void][NativeProbe]::FreeConsole()
 $attached=$false
 for($n=0;$n -lt 100 -and !$attached;$n++){ $attached=[NativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw 'AttachConsole failed'}
 # The Dart launcher itself enables VT output; preserve its normal console baseline.
 $before=[NativeProbe]::State()
 Set-Content "$file.ready" ready
 Start-Sleep -Seconds 7
 $during=[NativeProbe]::State()
 $parts=$during.Split(':')
 if (([int]$parts[1] -band 4) -eq 0) {throw "VT output not enabled: $during"}
 if ($Scenario -like 'help-*') {
  $isPassword=$Scenario.Contains('password')
  if($isPassword){[NativeProbe]::Text('secret')}else{[NativeProbe]::Key([char]0,0x25,0)}
  Start-Sleep -Milliseconds 300
  $editor=[NativeProbe]::EditorState()
  $screen=[NativeProbe]::ScreenText()
  [NativeProbe]::Key([char]20,84,8)
  Start-Sleep -Milliseconds 300
  $help=[NativeProbe]::ScreenText()
  if(!$help.Contains('Help:')){throw 'help did not open'}
  if($help.Contains('secret')){throw 'help disclosed hidden entry'}
  # Reopening help must not nest screens or lose the original editor.
  [NativeProbe]::Key([char]20,84,8)
  Start-Sleep -Milliseconds 300
  [NativeProbe]::Key([char]27,27,0)
  Start-Sleep -Milliseconds 300
  $dismissed=[NativeProbe]::ScreenText()
  if($dismissed.Contains('Help:')){throw 'dismissed help remains on screen'}
  if($dismissed -ne $screen){throw 'dismissal did not restore the original screen'}
  if([NativeProbe]::EditorState() -ne $editor){throw 'dismissal misplaced the editor caret'}
  if($Scenario.Contains('interrupt')) {
   [NativeProbe]::Key([char]20,84,8)
   Start-Sleep -Milliseconds 300
   [NativeProbe]::Key([char]3,67,8)
  } elseif($Scenario.Contains('eof')) {
   [NativeProbe]::Key([char]20,84,8)
   Start-Sleep -Milliseconds 300
   [NativeProbe]::Key([char]26,90,8)
  } elseif($isPassword){[NativeProbe]::Text("`rsubmit`r")}else{[NativeProbe]::Text("X`r")}
 } else {
 switch ($Scenario) {
  'linear-cursor' {
   if([int]$parts[3] -eq 0){throw "active editor cursor is hidden: $during"}
   $initial=[NativeProbe]::EditorState()
   if($initial -notmatch '^7:([0-9]+):> alpha$'){throw "initial cursor is not after the editable default: $initial"}
   $row=$Matches[1]
   [NativeProbe]::Key([char]0,0x24,0)
   Start-Sleep -Milliseconds 300
   $atHome=[NativeProbe]::EditorState()
   if($atHome -ne "2:${row}:> alpha"){throw "Home misplaced the cursor: $atHome"}
   [NativeProbe]::Key([char]0,0x23,0)
   Start-Sleep -Milliseconds 300
   $end=[NativeProbe]::EditorState()
   if($end -ne $initial){throw "End redrew onto another line or misplaced the cursor: $end"}
   [NativeProbe]::Key([char]0,0x25,0)
   [NativeProbe]::Text('X')
   Start-Sleep -Milliseconds 300
   $edited=[NativeProbe]::EditorState()
   if($edited -ne "7:${row}:> alphXa"){throw "insertion misplaced the cursor: $edited"}
   [NativeProbe]::Text("`r")
  }
  'linear-long' {
   if([int]$parts[3] -eq 0){throw "active editor cursor is hidden: $during"}
   $initial=[NativeProbe]::EditorState()
   if($initial -notmatch '^([0-9]+):([0-9]+):> <[0-9]+89$'){throw "long default is not clipped onto one editable line: $initial"}
   $row=$Matches[2]
   [NativeProbe]::Key([char]0,0x24,0)
   Start-Sleep -Milliseconds 300
   $atHome=[NativeProbe]::EditorState()
   if($atHome -notmatch "^2:${row}:> 0123456789[0-9]+>$"){throw "Home left the long editor row or stale text: $atHome"}
   [NativeProbe]::Key([char]0,0x23,0)
   Start-Sleep -Milliseconds 300
   $end=[NativeProbe]::EditorState()
   if($end -ne $initial){throw "End moved or corrupted the long editor: $end"}
   [NativeProbe]::Key([char]0,0x25,0)
   [NativeProbe]::Text('X')
   Start-Sleep -Milliseconds 300
   $edited=[NativeProbe]::EditorState()
   if($edited -notmatch "^[0-9]+:${row}:> <[0-9]+8X9$"){throw "long-line insertion left stale or wrapped text: $edited"}
   [NativeProbe]::Text("`r")
  }
  'repeat' { [NativeProbe]::Text("`r`r") }
  'error' { [NativeProbe]::Text("`r`r") }
  'eof' { [NativeProbe]::Key([char]26,90,8) }
  'escape' { [NativeProbe]::Key([char]27,27,0) }
  'concurrent' { [NativeProbe]::Text("`r") }
  'rich' { [NativeProbe]::Text("`r") }
  'dumb-auto' { [NativeProbe]::Text("`r") }
  'dumb-rich' { }
  'redirected' { [NativeProbe]::Text("`r") }
  'stdout' { [NativeProbe]::Text("`r") }
  'paste' { [NativeProbe]::Text("$([char]27)[200~/cancel$([char]27)[201~`r") }
  'unicode' { [NativeProbe]::Text("$([char]::ConvertFromUtf32(0x1f600))`r") }
  'interrupt' { [NativeProbe]::Key([char]3,67,8) }
  default { throw "Unknown scenario $Scenario" }
 }
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
 $expected = switch ($Scenario) { 'linear-cursor' { 'alphXa' } 'linear-long' { ('0123456789' * 29) + '012345678X9' } 'repeat' { 'alpha,alpha' } 'error' { 'alpha' } 'eof' { 'eof' } 'escape' { 'cancel' } 'concurrent' { 'busy,alpha' } 'rich' { 'alpha' } 'dumb-auto' { 'alpha' } 'dumb-rich' { 'unavailable:Rich interaction unavailable on the selected output; use linear or automatic mode.' } 'redirected' { 'alpha' } 'stdout' { 'alpha' } 'paste' { '/cancel' } 'unicode' { '1f600' } 'interrupt' { 'interrupt' } }
 if($Scenario -like 'help-*') {
  $expected=if($Scenario.Contains('interrupt')){'interrupt'}elseif($Scenario.Contains('eof')){'eof'}elseif($isPassword){'accepted'}else{'alphXa'}
  if([NativeProbe]::ScreenText().Contains('Help:')){throw 'help screen survived prompt exit'}
 }
 if($actual -ne $expected){throw "unexpected result: $actual"}
 if($Scenario -eq 'redirected') {
  $transcript = Get-Content "$file.stderr" -Raw
  if ($transcript.Contains([char]27) -or !$transcript.Contains('Name')) { throw 'unstable redirected output' }
 }
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content $Report "text input $Scenario PASS result=$actual state=$before -> $during -> $after"
} catch { Set-Content $Report "text input $Scenario FAIL $_"; throw }
finally { [void][NativeProbe]::FreeConsole(); if($p -and !$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}; Remove-Item $file,"$file.ready","$file.done","$file.stderr" -Force -ErrorAction SilentlyContinue }
