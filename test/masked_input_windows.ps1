param([string]$Scenario = 'rich', [string]$Target = 'elapsed', [string]$Report = (Join-Path $env:TEMP 'prompty-probe-report.txt'))
$ErrorActionPreference = 'Stop'
Remove-Item $Report -Force -ErrorAction SilentlyContinue
Add-Type @"
using System;
using System.Text;
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
 [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X, Y; }
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public short Left, Top, Right, Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct BufferInfo { public Coord Size, Cursor; public ushort Attributes; public Rect Window; public Coord Maximum; }
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleScreenBufferInfo(IntPtr h, out BufferInfo info);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacter(IntPtr h, StringBuilder chars, uint length, Coord start, out uint read);
 public static string Screen() {
  var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { BufferInfo b; uint n; if(!GetConsoleScreenBufferInfo(h,out b)) throw new Exception("buffer info failed"); var size=(uint)(b.Size.X*b.Size.Y); var text=new StringBuilder((int)size); if(!ReadConsoleOutputCharacter(h,text,size,new Coord(),out n)) throw new Exception("screen read failed"); return text.ToString(); }
  finally { CloseHandle(h); }
 }
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
$line = "Set-Location '$root'; Start-Sleep -Seconds 3; & '$dart' run test/masked_input_native_app.dart $Scenario $Target > '$file'; Set-Content '$file.done' done; Start-Sleep -Seconds 20"
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
 $expected = '1-2'
 if ($Target -eq 'adaptive') {
   [NativeProbe]::Text("12`r")
   if ($Scenario -eq 'linear') { [NativeProbe]::Text("/template`r2`r/done`r") }
   else { [NativeProbe]::Text("2`r") }
 } elseif ($Target -eq 'paste') {
   [NativeProbe]::Text("$([char]27)[200~1-2$([char]27)[201~")
   [NativeProbe]::Text("`r")
   if ($Scenario -eq 'linear') { [NativeProbe]::Text("/done`r") }
 } else {
   [NativeProbe]::Text('12')
   if ($Scenario -eq 'linear') { [NativeProbe]::Text("`r") }
   $found=$false
   for($n=0;$n -lt 100 -and !$found;$n++){ Start-Sleep -Milliseconds 100; $found=[NativeProbe]::Screen().Contains('Slot 2:') }
   if(!$found){throw 'native review missing: Slot 2:'}
   if ($Scenario -eq 'linear') { [NativeProbe]::Text("/done`r") }
   else { [NativeProbe]::Text("`r") }
 }

 for($n=0;$n -lt 100;$n++){if((Test-Path $file) -and (Get-Item $file).Length -gt 0){break}; Start-Sleep -Milliseconds 100}

 for($n=0;$n -lt 100 -and !(Test-Path "$file.done");$n++){Start-Sleep -Milliseconds 100}
 if (!(Test-Path "$file.done")) { throw "probe process did not exit" }
 $actual=(Get-Content $file -Raw).Trim()
 $after=''; for($n=0;$n -lt 100;$n++){ $after=[NativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
 if($actual -ne $expected){throw "unexpected result: $actual"}
 if($before -ne $after){throw "console state changed: $before -> $after"}
 Set-Content $Report "masked input $Target $Scenario PASS result=$actual state=$before -> $during -> $after"
} catch { Set-Content $Report "masked input FAIL $_"; throw }
finally { [void][NativeProbe]::FreeConsole(); if($p -and !$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}; Remove-Item $file,"$file.done","$file.stderr" -Force -ErrorAction SilentlyContinue }
