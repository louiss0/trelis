# Feed the pseudoconsole pipe, not WriteConsoleInput: the latter bypasses VT decoding.
param([switch]$Child, [string]$Result)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
public static class MultilinePty {
 [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X,Y; }
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct SI {
  public int cb; public string reserved,desktop,title; public int x,y,cx,cy,xc,yc,fill,flags; public short show,reserved2; public IntPtr data,input,output,error;
 }
 [StructLayout(LayoutKind.Sequential)] public struct SX { public SI si; public IntPtr attrs; }
 [StructLayout(LayoutKind.Sequential)] public struct PI { public IntPtr process,thread; public uint pid,tid; }
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool CreatePipe(out IntPtr r,out IntPtr w,IntPtr sa,uint size);
 [DllImport("kernel32.dll")] static extern int CreatePseudoConsole(Coord size,IntPtr input,IntPtr output,uint flags,out IntPtr pc);
 [DllImport("kernel32.dll")] static extern void ClosePseudoConsole(IntPtr pc);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr p,int count,int flags,ref IntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr p,uint flags,IntPtr attr,IntPtr value,IntPtr size,IntPtr old,IntPtr ret);
 [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr p);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder cmd,IntPtr psa,IntPtr tsa,bool inherit,uint flags,IntPtr env,string cwd,ref SX si,out PI pi);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")] static extern bool ReadFile(IntPtr h,byte[] b,uint n,out uint read,IntPtr ov);
 [DllImport("kernel32.dll")] static extern bool WriteFile(IntPtr h,byte[] b,uint n,out uint written,IntPtr ov);
 [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h,uint ms);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h,uint exit);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr sa,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll")] static extern bool SetStdHandle(int n,IntPtr h);
 [DllImport("kernel32.dll")] static extern bool SetHandleInformation(IntPtr h,uint mask,uint flags);
 static void Check(bool ok) { if(!ok) throw new Exception("Win32 error "+Marshal.GetLastWin32Error()); }
 public static void App(string dart,string root,string result) {
  var input=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  var output=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try {
   Check(SetHandleInformation(input,1,1)); Check(SetHandleInformation(output,1,1));
   Check(SetStdHandle(-10,input)); Check(SetStdHandle(-12,output));
   var start=new System.Diagnostics.ProcessStartInfo(dart,"run test/multiline_native_app.dart linear");
   start.WorkingDirectory=root; start.UseShellExecute=false; start.RedirectStandardOutput=true;
   start.EnvironmentVariables["TERM"]="xterm-256color";
   using(var p=System.Diagnostics.Process.Start(start)) {
    var text=p.StandardOutput.ReadToEndAsync();
    if(!p.WaitForExit(20000)) { p.Kill(); p.WaitForExit(); throw new Exception("Dart prompt timed out"); }
    if(p.ExitCode!=0) throw new Exception("Dart prompt failed: "+p.ExitCode);
    System.IO.File.WriteAllText(result,text.GetAwaiter().GetResult());
   }
  } finally { CloseHandle(input); CloseHandle(output); }
 }
 public static void Run(string command,string input) {
  IntPtr ir=IntPtr.Zero,iw=IntPtr.Zero,or=IntPtr.Zero,ow=IntPtr.Zero,pc=IntPtr.Zero,attrs=IntPtr.Zero;
  PI pi=new PI(); Task drain=null; var initialized=false;
  try {
   Check(CreatePipe(out ir,out iw,IntPtr.Zero,0)); Check(CreatePipe(out or,out ow,IntPtr.Zero,0));
   if(CreatePseudoConsole(new Coord{X=100,Y=30},ir,ow,0,out pc)!=0) throw new Exception("CreatePseudoConsole failed");
   CloseHandle(ir); ir=IntPtr.Zero; CloseHandle(ow); ow=IntPtr.Zero;
   var output=new StringBuilder();
   drain=Task.Run(()=>{var b=new byte[4096]; uint n; while(ReadFile(or,b,(uint)b.Length,out n,IntPtr.Zero)&&n>0) { lock(output) output.Append(Encoding.UTF8.GetString(b,0,(int)n)); } });
   IntPtr size=IntPtr.Zero; InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref size);
   attrs=Marshal.AllocHGlobal(size);
   Check(InitializeProcThreadAttributeList(attrs,1,0,ref size));
   initialized=true;
   Check(UpdateProcThreadAttribute(attrs,0,new IntPtr(0x20016),pc,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero));
   var sx=new SX{si=new SI{cb=Marshal.SizeOf(typeof(SX))},attrs=attrs};
   Check(CreateProcess(null,new StringBuilder(command),IntPtr.Zero,IntPtr.Zero,false,0x80000,IntPtr.Zero,null,ref sx,out pi));
   var until=DateTime.UtcNow.AddSeconds(30); var ready=false;
   while(DateTime.UtcNow<until) { lock(output) ready=output.ToString().Contains("Identified paste is literal"); if(ready) break; Thread.Sleep(20); }
   if(!ready) { lock(output) throw new Exception("Multiline did not become ready: "+output); }
   var bytes=Encoding.UTF8.GetBytes(input); uint written;
   Check(WriteFile(iw,bytes,(uint)bytes.Length,out written,IntPtr.Zero));
   if(written!=bytes.Length) throw new Exception("Incomplete input write");
   if(WaitForSingleObject(pi.process,20000)!=0) throw new Exception("Multiline did not finish");
  } finally {
   if(pi.process!=IntPtr.Zero) { if(WaitForSingleObject(pi.process,0)!=0) TerminateProcess(pi.process,1); CloseHandle(pi.process); CloseHandle(pi.thread); }
   if(ir!=IntPtr.Zero) CloseHandle(ir); if(ow!=IntPtr.Zero) CloseHandle(ow);
   if(iw!=IntPtr.Zero) CloseHandle(iw); if(pc!=IntPtr.Zero) ClosePseudoConsole(pc);
   if(drain!=null) drain.Wait(2000); if(or!=IntPtr.Zero) CloseHandle(or);
   if(initialized) DeleteProcThreadAttributeList(attrs); if(attrs!=IntPtr.Zero) Marshal.FreeHGlobal(attrs);
  }
 }
}
'@
$root=Split-Path $PSScriptRoot -Parent
$dart=(Get-Command dart).Source
if($Child){[MultilinePty]::App($dart,$root,$Result); exit}
$esc=[char]27
$cases=@(
 @{Name='framed-command'; Keys="$esc[200~/cancel$esc[201~`r/done`r"; Expected='2f,63,61,6e,63,65,6c'},
 @{Name='typed-command'; Keys="/cancel`r"; Expected='cancel'},
 @{Name='framed-multiline'; Keys="$esc[200~x`r`n/cancel$esc[201~`r/done`r"; Expected='78,a,2f,63,61,6e,63,65,6c'},
 @{Name='editing'; Keys="abx$esc[D$esc[3~c`r/done`r"; Expected='61,62,63'},
 @{Name='function-key'; Keys="$esc`OPabc`r/done`r"; Expected='61,62,63'},
 @{Name='application-navigation'; Keys="abx$esc`OH$esc`OC$esc`OC$esc[3~c`r/done`r"; Expected='61,62,63'}
)
foreach($case in $cases) {
 $file=Join-Path $env:TEMP ("multiline-conpty-"+[guid]::NewGuid()+'.txt')
 try {
  # Explicit console handles prevent the runner's redirected handles leaking in.
  $command="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Child -Result `"$file`""
  try { [MultilinePty]::Run($command,$case.Keys) }
  catch { if(Test-Path $file){Get-Content $file}; throw }
  $actual=(Get-Content $file -Raw).Trim()
  if($actual -ne $case.Expected){throw "$($case.Name): expected $($case.Expected), got $actual"}
  Write-Output "$($case.Name) PASS"
 } finally { Remove-Item $file -Force -ErrorAction SilentlyContinue }
}
