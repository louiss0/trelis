# Feed the pseudoconsole pipe, not WriteConsoleInput: the latter bypasses VT decoding.
# Input is staged against bounded observable transcript conditions. Diagnostic
# artifacts are retained only for failing scenarios; successful scenario
# directories, including result files and transcripts, are removed.
param(
  [switch]$Child,
  [string]$Result,
  [string]$Mode = 'linear',
  [string]$Scenario,
  [string]$ArtifactRoot = (Join-Path $env:TEMP 'multiline-conpty-artifacts'),
  [int]$StartupTimeoutMs = 30000,
  [int]$InteractionTimeoutMs = 5000,
  [int]$ProcessTimeoutMs = 30000
)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class MultilinePtyStage {
  public string Name = "";
  public string Phase = "interaction";
  public string Input = "";
  public string WaitFor = "";
  public bool SearchNewOutput = true;
  public int TimeoutMilliseconds = 5000;
}

public class MultilinePtyResult {
  public bool Success;
  public string Error = "";
  public string FailurePhase = "";
  public string FailureStage = "";
  public string Transcript = "";
  public bool ProcessExited;
  public bool HasExitCode;
  public int ExitCode = -1;
  public uint ProcessId;
  public double ElapsedMilliseconds;
  public double PhaseElapsedMilliseconds;
  public double WaitElapsedMilliseconds;
}

public static class MultilinePty {
 [StructLayout(LayoutKind.Sequential)] public struct Coord { public short X,Y; }
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct SI {
  public int cb; public string reserved,desktop,title; public int x,y,cx,cy,xc,yc,fill,flags; public short show,reserved2; public IntPtr data,input,output,error;
 }
 [StructLayout(LayoutKind.Sequential)] public struct SX { public SI si; public IntPtr attrs; }
 [StructLayout(LayoutKind.Sequential)] public struct PI { public IntPtr process,thread; public uint pid,tid; }
 [StructLayout(LayoutKind.Sequential)] public struct IOCounters {
  public ulong ReadOperationCount,WriteOperationCount,OtherOperationCount,ReadTransferCount,WriteTransferCount,OtherTransferCount;
 }
 [StructLayout(LayoutKind.Sequential)] public struct JobBasicLimit {
  public long PerProcessUserTimeLimit,PerJobUserTimeLimit;
  public uint LimitFlags;
  public UIntPtr MinimumWorkingSetSize,MaximumWorkingSetSize;
  public uint ActiveProcessLimit;
  public UIntPtr Affinity;
  public uint PriorityClass,SchedulingClass;
 }
 [StructLayout(LayoutKind.Sequential)] public struct JobExtendedLimit {
  public JobBasicLimit BasicLimitInformation;
  public IOCounters IoInfo;
  public UIntPtr ProcessMemoryLimit,JobMemoryLimit,PeakProcessMemoryLimit,PeakJobMemoryLimit;
 }
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool CreatePipe(out IntPtr r,out IntPtr w,IntPtr sa,uint size);
 [DllImport("kernel32.dll")] static extern int CreatePseudoConsole(Coord size,IntPtr input,IntPtr output,uint flags,out IntPtr pc);
 [DllImport("kernel32.dll")] static extern void ClosePseudoConsole(IntPtr pc);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr p,int count,int flags,ref IntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr p,uint flags,IntPtr attr,IntPtr value,IntPtr size,IntPtr old,IntPtr ret);
 [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr p);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder cmd,IntPtr psa,IntPtr tsa,bool inherit,uint flags,IntPtr env,string cwd,ref SX si,out PI pi);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")] static extern bool ReadFile(IntPtr h,byte[] b,uint n,out uint read,IntPtr ov);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool WriteFile(IntPtr h,byte[] b,uint n,out uint written,IntPtr ov);
 [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h,uint ms);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h,uint exit);
 [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h,out uint exit);
 [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int infoClass,IntPtr info,uint length);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll")] static extern bool TerminateJobObject(IntPtr job,uint exit);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string name,uint access,uint share,IntPtr sa,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll")] static extern bool SetStdHandle(int n,IntPtr h);
 [DllImport("kernel32.dll")] static extern bool SetHandleInformation(IntPtr h,uint mask,uint flags);

 static void Check(bool ok) { if(!ok) throw new Exception("Win32 error "+Marshal.GetLastWin32Error()); }

 static string Snapshot(StringBuilder output) {
  lock(output) return output.ToString();
 }

 static bool TranscriptContains(StringBuilder output,string needle,int offset) {
  lock(output) {
   string text=output.ToString();
   if(offset<0) offset=0;
   if(offset>text.Length) offset=text.Length;
   if(String.IsNullOrEmpty(needle)) return text.Length>offset;
   return text.IndexOf(needle,offset,StringComparison.Ordinal)>=0;
  }
 }

 static void CaptureExitIfAvailable(PI pi,MultilinePtyResult result) {
  if(pi.process==IntPtr.Zero) return;
  if(WaitForSingleObject(pi.process,0)!=0) return;
  uint code;
  if(GetExitCodeProcess(pi.process,out code)) {
   result.ProcessExited=true;
   result.HasExitCode=true;
   result.ExitCode=unchecked((int)code);
  }
 }

 public static int App(string dart,string root,string result,string scenario) {
  var input=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  var output=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  int exitCode=1;
  try {
   Check(SetHandleInformation(input,1,1)); Check(SetHandleInformation(output,1,1));
   Check(SetStdHandle(-10,input)); Check(SetStdHandle(-12,output));
   var start=new ProcessStartInfo(dart,"run test/multiline_native_app.dart "+scenario);
   start.WorkingDirectory=root; start.UseShellExecute=false; start.RedirectStandardOutput=true;
   start.EnvironmentVariables["TERM"]="xterm-256color";
   using(var p=Process.Start(start)) {
    var text=p.StandardOutput.ReadToEndAsync();
    if(!p.WaitForExit(20000)) {
     try { p.Kill(); p.WaitForExit(); } catch { }
     try { System.IO.File.WriteAllText(result,text.GetAwaiter().GetResult()); } catch { }
     System.IO.File.WriteAllText(result+".child-error","Dart prompt timed out after 20000 ms and was killed.");
     exitCode=2;
    } else {
     string stdout=text.GetAwaiter().GetResult();
     System.IO.File.WriteAllText(result,stdout);
     System.IO.File.WriteAllText(result+".dart-exitcode",p.ExitCode.ToString(System.Globalization.CultureInfo.InvariantCulture));
     if(p.ExitCode!=0) {
      System.IO.File.WriteAllText(result+".child-error","Dart prompt failed with exit code "+p.ExitCode+".");
      exitCode=p.ExitCode;
     } else exitCode=0;
    }
   }
  } catch(Exception ex) {
   try { System.IO.File.WriteAllText(result+".child-error",ex.ToString()); } catch { }
   exitCode=1;
  } finally {
   if(input!=IntPtr.Zero) CloseHandle(input);
   if(output!=IntPtr.Zero) CloseHandle(output);
  }
  return exitCode;
 }

 public static MultilinePtyResult Run(string command,MultilinePtyStage[] stages,int processTimeoutMilliseconds) {
  var result=new MultilinePtyResult();
  var total=Stopwatch.StartNew();
  var phaseWatch=Stopwatch.StartNew();
  IntPtr ir=IntPtr.Zero,iw=IntPtr.Zero,or=IntPtr.Zero,ow=IntPtr.Zero,pc=IntPtr.Zero,attrs=IntPtr.Zero,job=IntPtr.Zero;
  PI pi=new PI(); Task drain=null; var initialized=false;
  var output=new StringBuilder();
  string phase="setup";
  string stageName="";
  int outputMarker=0;
  try {
   job=CreateJobObject(IntPtr.Zero,null);
   if(job==IntPtr.Zero) throw new Exception("CreateJobObject failed with Win32 error "+Marshal.GetLastWin32Error());
   var limit=new JobExtendedLimit();
   limit.BasicLimitInformation.LimitFlags=0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
   IntPtr limitPtr=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(JobExtendedLimit)));
   try {
    Marshal.StructureToPtr(limit,limitPtr,false);
    Check(SetInformationJobObject(job,9,limitPtr,(uint)Marshal.SizeOf(typeof(JobExtendedLimit))));
   } finally { Marshal.FreeHGlobal(limitPtr); }

   Check(CreatePipe(out ir,out iw,IntPtr.Zero,0)); Check(CreatePipe(out or,out ow,IntPtr.Zero,0));
   if(CreatePseudoConsole(new Coord{X=100,Y=30},ir,ow,0,out pc)!=0) throw new Exception("CreatePseudoConsole failed");
   CloseHandle(ir); ir=IntPtr.Zero; CloseHandle(ow); ow=IntPtr.Zero;
   drain=Task.Run(()=>{var b=new byte[4096]; uint n; while(ReadFile(or,b,(uint)b.Length,out n,IntPtr.Zero)&&n>0) { lock(output) output.Append(Encoding.UTF8.GetString(b,0,(int)n)); } });
   IntPtr size=IntPtr.Zero; InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref size);
   attrs=Marshal.AllocHGlobal(size);
   Check(InitializeProcThreadAttributeList(attrs,1,0,ref size));
   initialized=true;
   Check(UpdateProcThreadAttribute(attrs,0,new IntPtr(0x20016),pc,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero));
   var sx=new SX{si=new SI{cb=Marshal.SizeOf(typeof(SX))},attrs=attrs};
   // CREATE_SUSPENDED|EXTENDED_STARTUPINFO_PRESENT lets the process join the
   // kill-on-close job before it can create descendants.
   Check(CreateProcess(null,new StringBuilder(command),IntPtr.Zero,IntPtr.Zero,false,0x80004u,IntPtr.Zero,null,ref sx,out pi));
   result.ProcessId=pi.pid;
   Check(AssignProcessToJobObject(job,pi.process));
   if(ResumeThread(pi.thread)==0xffffffffu) throw new Exception("ResumeThread failed with Win32 error "+Marshal.GetLastWin32Error());

   for(int i=0;i<stages.Length;i++) {
    var stage=stages[i];
    stageName=stage.Name ?? "";
    phase=String.IsNullOrEmpty(stage.Phase)?"interaction":stage.Phase;
    int timeout=stage.TimeoutMilliseconds>0?stage.TimeoutMilliseconds:5000;
    phaseWatch.Restart();
    int offset=stage.SearchNewOutput?outputMarker:0;
    bool ready=false;
    while(true) {
     ready=TranscriptContains(output,stage.WaitFor,offset);
     if(ready || phaseWatch.ElapsedMilliseconds>=timeout) break;
     Thread.Sleep(20);
    }
    result.WaitElapsedMilliseconds=phaseWatch.Elapsed.TotalMilliseconds;
    if(!ready) {
     string condition=String.IsNullOrEmpty(stage.WaitFor)?"<new terminal output>":stage.WaitFor;
     throw new Exception("Timed out after "+timeout+" ms waiting for transcript condition '"+condition+"' in stage '"+stageName+"'.");
    }
    if(!String.IsNullOrEmpty(stage.Input)) {
     phaseWatch.Restart();
     string before=Snapshot(output);
     outputMarker=before.Length;
     var bytes=Encoding.UTF8.GetBytes(stage.Input);
     int writtenTotal=0;
     while(writtenTotal<bytes.Length) {
      int remaining=bytes.Length-writtenTotal;
      var chunk=new byte[remaining];
      Array.Copy(bytes,writtenTotal,chunk,0,remaining);
      uint written;
      Check(WriteFile(iw,chunk,(uint)chunk.Length,out written,IntPtr.Zero));
      if(written==0) throw new Exception("Pseudoconsole input write made no progress");
      writtenTotal+=(int)written;
     }
    }
   }

   phase="process-exit";
   stageName="";
   phaseWatch.Restart();
   uint wait=WaitForSingleObject(pi.process,(uint)processTimeoutMilliseconds);
   if(wait==0x102) throw new Exception("Child process did not finish within "+processTimeoutMilliseconds+" ms.");
   if(wait!=0) throw new Exception("Waiting for the child process failed with result "+wait+".");
   CaptureExitIfAvailable(pi,result);
   if(!result.HasExitCode) throw new Exception("Child process finished but its exit status was unavailable.");
   if(result.ExitCode!=0) throw new Exception("Child process exited with code "+result.ExitCode+".");
   result.Success=true;
  } catch(Exception ex) {
   result.Success=false;
   result.Error=ex.Message;
   result.FailurePhase=phase;
   result.FailureStage=stageName;
   result.PhaseElapsedMilliseconds=phaseWatch.Elapsed.TotalMilliseconds;
   CaptureExitIfAvailable(pi,result);
  } finally {
   if(!result.Success && job!=IntPtr.Zero) TerminateJobObject(job,1);
   if(pi.process!=IntPtr.Zero) {
    if(WaitForSingleObject(pi.process,0)!=0) TerminateProcess(pi.process,1);
    CloseHandle(pi.process);
   }
   if(pi.thread!=IntPtr.Zero) CloseHandle(pi.thread);
   if(ir!=IntPtr.Zero) CloseHandle(ir); if(ow!=IntPtr.Zero) CloseHandle(ow);
   if(iw!=IntPtr.Zero) CloseHandle(iw); if(pc!=IntPtr.Zero) ClosePseudoConsole(pc);
   if(drain!=null) drain.Wait(2000); if(or!=IntPtr.Zero) CloseHandle(or);
   if(initialized) DeleteProcThreadAttributeList(attrs); if(attrs!=IntPtr.Zero) Marshal.FreeHGlobal(attrs);
   if(job!=IntPtr.Zero) CloseHandle(job);
   result.Transcript=Snapshot(output);
   result.ElapsedMilliseconds=total.Elapsed.TotalMilliseconds;
   if(result.Success) result.PhaseElapsedMilliseconds=phaseWatch.Elapsed.TotalMilliseconds;
  }
  return result;
 }
}
'@

function New-PtyStage {
  param(
    [string]$Name,
    [string]$Phase,
    [string]$WaitFor,
    [string]$Keys,
    [bool]$SearchNewOutput = $true,
    [int]$TimeoutMilliseconds = 5000
  )
  $stage = New-Object MultilinePtyStage
  $stage.Name = $Name
  $stage.Phase = $Phase
  $stage.WaitFor = $WaitFor
  $stage.Input = $Keys
  $stage.SearchNewOutput = $SearchNewOutput
  $stage.TimeoutMilliseconds = $TimeoutMilliseconds
  return $stage
}

function Get-TextFileOrNull {
  param([string]$Path)
  if(Test-Path -LiteralPath $Path) { return Get-Content -LiteralPath $Path -Raw }
  return $null
}

function Write-ConptyFailureArtifacts {
  param(
    [hashtable]$Case,
    [object]$Run,
    [string]$ArtifactDirectory,
    [string]$ResultFile,
    [string]$Phase,
    [string]$Expected,
    [string]$Actual,
    [string]$ErrorMessage
  )
  $transcript = ''
  $stageName = ''
  $elapsed = $null
  $phaseElapsed = $null
  $waitElapsed = $null
  $processExited = $false
  $hasExitCode = $false
  $exitCode = $null
  $processId = $null
  if($null -ne $Run) {
    $transcript = [string]$Run.Transcript
    $stageName = [string]$Run.FailureStage
    $elapsed = $Run.ElapsedMilliseconds
    $phaseElapsed = $Run.PhaseElapsedMilliseconds
    $waitElapsed = $Run.WaitElapsedMilliseconds
    $processExited = [bool]$Run.ProcessExited
    $hasExitCode = [bool]$Run.HasExitCode
    if($hasExitCode) { $exitCode = $Run.ExitCode }
    $processId = $Run.ProcessId
  }

  $transcriptPath = Join-Path $ArtifactDirectory 'transcript.txt'
  [System.IO.File]::WriteAllText($transcriptPath,$transcript)

  $dartExitText = Get-TextFileOrNull "$ResultFile.dart-exitcode"
  $dartExitCode = $null
  if($null -ne $dartExitText) {
    $parsed = 0
    if([int]::TryParse($dartExitText.Trim(),[ref]$parsed)) { $dartExitCode = $parsed }
  }
  $childError = Get-TextFileOrNull "$ResultFile.child-error"
  $resultPresent = Test-Path -LiteralPath $ResultFile
  $resultText = Get-TextFileOrNull $ResultFile
  $stages = @($Case.Stages | ForEach-Object {
    [ordered]@{
      name = $_.Name
      phase = $_.Phase
      waitFor = $_.WaitFor
      searchNewOutput = $_.SearchNewOutput
      timeoutMilliseconds = $_.TimeoutMilliseconds
      input = $_.Input
    }
  })

  $diagnostic = [ordered]@{
    scenario = $Case.Name
    phase = $Phase
    stage = $stageName
    elapsedMilliseconds = $elapsed
    phaseElapsedMilliseconds = $phaseElapsed
    waitElapsedMilliseconds = $waitElapsed
    childExitStatus = [ordered]@{
      processId = $processId
      processExited = $processExited
      hasExitCode = $hasExitCode
      exitCode = $exitCode
      dartExitCode = $dartExitCode
      childError = $childError
    }
    expectedResult = $Expected
    actualResult = $Actual
    resultFilePresent = $resultPresent
    resultFile = $ResultFile
    resultFileContent = $resultText
    artifactDirectory = $ArtifactDirectory
    transcriptFile = $transcriptPath
    transcript = $transcript
    error = $ErrorMessage
    inputStages = $stages
  }

  $json = $diagnostic | ConvertTo-Json -Depth 8
  [System.IO.File]::WriteAllText((Join-Path $ArtifactDirectory 'diagnostic.json'),$json)
  $summary = @(
    "scenario=$($Case.Name)",
    "phase=$Phase",
    "stage=$stageName",
    "elapsedMilliseconds=$elapsed",
    "phaseElapsedMilliseconds=$phaseElapsed",
    "waitElapsedMilliseconds=$waitElapsed",
    "processExited=$processExited",
    "exitCode=$exitCode",
    "dartExitCode=$dartExitCode",
    "expected=$Expected",
    "actual=$Actual",
    "resultFilePresent=$resultPresent",
    "artifactDirectory=$ArtifactDirectory",
    "error=$ErrorMessage",
    '',
    '--- terminal transcript ---',
    $transcript
  )
  [System.IO.File]::WriteAllLines((Join-Path $ArtifactDirectory 'failure.txt'),$summary)
  return $diagnostic
}

function Format-ConptyDiagnostic {
  param([object]$Diagnostic)
  $child = $Diagnostic['childExitStatus']
  $exit = 'unavailable'
  if($child['hasExitCode']) { $exit = [string]$child['exitCode'] }
  return "phase=$($Diagnostic['phase']) stage=$($Diagnostic['stage']) elapsedMs=$($Diagnostic['elapsedMilliseconds']) waitMs=$($Diagnostic['waitElapsedMilliseconds']) childExit=$exit expected=$($Diagnostic['expectedResult']) resultFilePresent=$($Diagnostic['resultFilePresent']) artifact=$($Diagnostic['artifactDirectory']) error=$($Diagnostic['error'])"
}

$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
if($Child) {
  $childExit = [MultilinePty]::App($dart,$root,$Result,$Mode)
  exit $childExit
}

$esc = [char]27
$linearReady = 'Identified paste is literal'
$richReady = 'Ctrl+J finishes the answer'
$cases = @(
  @{
    Name='framed-command'; Mode='linear'; Expected='2f,63,61,6e,63,65,6c'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $linearReady -Keys "$esc[200~/cancel$esc[201~" -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'framed-paste-painted' -Phase 'interaction' -WaitFor '/cancel' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'line-accepted' -Phase 'interaction' -WaitFor '' -Keys '/done' -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'done-painted' -Phase 'interaction' -WaitFor '/done' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='typed-command'; Mode='linear'; Expected='cancel'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $linearReady -Keys '/cancel' -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'command-painted' -Phase 'interaction' -WaitFor '/cancel' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='framed-multiline'; Mode='linear'; Expected='78,a,2f,63,61,6e,63,65,6c'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $linearReady -Keys "$esc[200~x`r`n/cancel$esc[201~" -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'framed-paste-painted' -Phase 'interaction' -WaitFor '/cancel' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'line-accepted' -Phase 'interaction' -WaitFor '' -Keys '/done' -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'done-painted' -Phase 'interaction' -WaitFor '/done' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='editing'; Mode='linear'; Expected='61,62,63'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $linearReady -Keys 'abx' -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'initial-text-painted' -Phase 'interaction' -WaitFor 'abx' -Keys ("${esc}[D${esc}[3~" + 'c') -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'edited-text-painted' -Phase 'interaction' -WaitFor 'abc' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'line-accepted' -Phase 'interaction' -WaitFor '' -Keys '/done' -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'done-painted' -Phase 'interaction' -WaitFor '/done' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='f1-modal-help'; Mode='rich'; Expected='61,62,63'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $richReady -Keys "$esc`OP" -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      # Repeat F1 and type ordinary text while help owns input, then dismiss it.
      # Input ordering is real terminal input ordering; the transcript contract
      # below verifies that neither the repeated help key nor the modal noise
      # became another help screen or answer data.
      (New-PtyStage -Name 'help-opened' -Phase 'interaction' -WaitFor 'Help:' -Keys ("$esc`OP" + 'ModalNoise9' + $esc) -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'help-dismissed' -Phase 'interaction' -WaitFor 'Line 1:' -Keys 'abc' -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'ordinary-input-painted' -Phase 'interaction' -WaitFor 'abc' -Keys "`n" -TimeoutMilliseconds $InteractionTimeoutMs)
    ); TranscriptCheck={
      param($transcript)
      $helpCount=[regex]::Matches($transcript,'Help:').Count
      if($helpCount -ne 1){return "expected exactly one non-nested help screen, saw $helpCount"}
      if($transcript.Contains('ModalNoise9')){return 'modal input was painted instead of swallowed'}
      $alternateEnter=[string][char]27+'[?1049h'
      $alternateLeave=[string][char]27+'[?1049l'
      $enterCount=[regex]::Matches($transcript,[regex]::Escape($alternateEnter)).Count
      $leaveCount=[regex]::Matches($transcript,[regex]::Escape($alternateLeave)).Count
      if($enterCount -ne 1 -or $leaveCount -ne 1){return "expected one alternate-screen help enter/leave pair, saw $enterCount/$leaveCount"}
      return $null
    }
  },
  @{
    # F5 is a recognized VT function-key encoding but has no Multiline binding:
    # it must neither contribute escape bytes as answer data nor prevent the
    # ordinary input that follows it in the same terminal stream.
    Name='unassigned-function-key'; Mode='rich'; Expected='61,62,63'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $richReady -Keys "$esc[15~abc" -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'ordinary-input-painted' -Phase 'interaction' -WaitFor 'abc' -Keys "`n" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='application-navigation'; Mode='linear'; Expected='61,62,63'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $linearReady -Keys 'abx' -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'initial-text-painted' -Phase 'interaction' -WaitFor 'abx' -Keys ("${esc}OH${esc}OC${esc}OC${esc}[3~" + 'c') -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'edited-text-painted' -Phase 'interaction' -WaitFor 'abc' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'line-accepted' -Phase 'interaction' -WaitFor '' -Keys '/done' -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'done-painted' -Phase 'interaction' -WaitFor '/done' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  },
  @{
    Name='rich-enter-ctrl-j'; Mode='rich'; Expected='6f,6e,65,a'; Stages=@(
      (New-PtyStage -Name 'startup-ready' -Phase 'startup' -WaitFor $richReady -Keys 'one' -SearchNewOutput $false -TimeoutMilliseconds $StartupTimeoutMs),
      (New-PtyStage -Name 'text-painted' -Phase 'interaction' -WaitFor 'one' -Keys "`r" -TimeoutMilliseconds $InteractionTimeoutMs),
      (New-PtyStage -Name 'newline-painted' -Phase 'interaction' -WaitFor 'Line 2:' -Keys "`n" -TimeoutMilliseconds $InteractionTimeoutMs)
    )
  }
)

$selectedCases = @($cases)
if(-not [string]::IsNullOrEmpty($Scenario)) {
  $selectedCases = @($cases | Where-Object { $_.Name -eq $Scenario })
  if($selectedCases.Count -eq 0) { throw "Unknown multiline ConPTY scenario '$Scenario'." }
}

New-Item -ItemType Directory -Force -Path $ArtifactRoot | Out-Null
$failures = @()
$successes = 0
foreach($case in $selectedCases) {
  $artifactDirectory = Join-Path $ArtifactRoot ($case.Name + '-' + [guid]::NewGuid().ToString('n'))
  New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
  $file = Join-Path $artifactDirectory 'result.txt'
  $run = $null
  $phase = 'startup'
  $actual = $null
  try {
    # Explicit console handles prevent the runner's redirected handles leaking in.
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Child -Mode $($case.Mode) -Result `"$file`""
    [MultilinePtyStage[]]$stages = $case.Stages
    $run = [MultilinePty]::Run($command,$stages,$ProcessTimeoutMs)
    if(-not $run.Success) {
      if(-not [string]::IsNullOrEmpty($run.FailurePhase)) { $phase = $run.FailurePhase }
      throw $run.Error
    }

    $phase = 'result-file'
    $childError = Get-TextFileOrNull "$file.child-error"
    if($null -ne $childError) { throw "Child helper reported an error: $childError" }
    if(-not (Test-Path -LiteralPath $file)) { throw "Result file is missing after a successful child process exit." }
    $actual = (Get-Content -LiteralPath $file -Raw).Trim()
    if($actual -ne $case.Expected) { throw "Expected result $($case.Expected), got $actual." }
    if($case.ContainsKey('TranscriptCheck') -and $null -ne $case.TranscriptCheck) {
      $phase = 'transcript-contract'
      $checker = $case.TranscriptCheck
      $transcriptError = & $checker $run.Transcript
      if(-not [string]::IsNullOrEmpty($transcriptError)) { throw "Transcript contract failed: $transcriptError" }
    }

    Write-Output "$($case.Name) PASS"
    $successes++
    Remove-Item -LiteralPath $artifactDirectory -Recurse -Force -ErrorAction SilentlyContinue
  } catch {
    if($null -ne $run -and -not $run.Success -and -not [string]::IsNullOrEmpty($run.FailurePhase)) { $phase = $run.FailurePhase }
    $diagnostic = Write-ConptyFailureArtifacts -Case $case -Run $run -ArtifactDirectory $artifactDirectory -ResultFile $file -Phase $phase -Expected $case.Expected -Actual $actual -ErrorMessage $_.Exception.Message
    Write-Output "$($case.Name) FAIL $(Format-ConptyDiagnostic $diagnostic)"
    $failures += $diagnostic
  }
}

if($failures.Count -eq 0) {
  if(-not (Get-ChildItem -LiteralPath $ArtifactRoot -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    Remove-Item -LiteralPath $ArtifactRoot -Force -ErrorAction SilentlyContinue
  }
  Write-Output "multiline-conpty PASS ($successes cases; diagnostic artifacts cleaned)"
} else {
  Write-Output "multiline-conpty FAIL ($($failures.Count) failing cases; artifacts retained under $ArtifactRoot)"
  exit 1
}
