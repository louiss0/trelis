param([string]$Scenario = 'repeat', [switch]$PublicApi, [string]$Report = (Join-Path $env:TEMP 'prompty-probe-report.txt'))
$ErrorActionPreference = 'Stop'
Remove-Item $Report -Force -ErrorAction SilentlyContinue
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeProbe {
 [StructLayout(LayoutKind.Explicit, Size=20, CharSet=CharSet.Unicode)] public struct Input {
  [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public int Down;
  [FieldOffset(8)] public ushort Repeat; [FieldOffset(10)] public ushort VK;
  [FieldOffset(12)] public ushort Scan; [FieldOffset(14)] public char Char; [FieldOffset(16)] public uint State;
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
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleScreenBufferSize(IntPtr h,Coord size);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleWindowInfo(IntPtr h,bool absolute,ref Rect window);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacter(IntPtr h,[Out] ushort[] text,uint length,Coord position,out uint read);
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInput(IntPtr h,Input[] records,uint length,out uint written);
 [DllImport("user32.dll")] static extern uint MapVirtualKeyW(uint code,uint mapType);
 static ushort ScanFor(ushort vk) { return (ushort)(MapVirtualKeyW(vk,0) & 0xffff); }
 public static void Resize(short columns, short rows) {
  var h=CreateFile("CONOUT$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try {
   var window=new Rect{Left=0,Top=0,Right=(short)(columns-1),Bottom=(short)(rows-1)};
   if(!SetConsoleWindowInfo(h,true,ref window)) throw new Exception("window resize error " + Marshal.GetLastWin32Error());
   var size=new Coord{X=columns,Y=rows};
   if(!SetConsoleScreenBufferSize(h,size)) throw new Exception("buffer resize error " + Marshal.GetLastWin32Error());
  } finally { CloseHandle(h); }
 }
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
  try { var a=new Input[text.Length*2]; for(int j=0;j<text.Length;j++){ var c=text[j]; var vk=(ushort)(c == '~' ? 192 : Char.ToUpper(c)); a[j*2]=new Input{Type=1,Down=1,Repeat=1,VK=vk,Scan=ScanFor(vk),Char=c}; a[j*2+1]=a[j*2]; a[j*2+1].Down=0; } uint n; if(!WriteConsoleInput(h,a,(uint)a.Length,out n)||n!=a.Length) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); } finally { CloseHandle(h); }
 }
 public static void Key(char c, ushort vk, uint state) {
  var h=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  try { var a=new Input[2]; a[0]=new Input{Type=1,Down=1,Repeat=1,VK=vk,Scan=ScanFor(vk),Char=c,State=state}; a[1]=a[0]; a[1].Down=0; uint n; if(!WriteConsoleInput(h,a,2,out n)||n!=2) throw new Exception("inject failed " + Marshal.GetLastWin32Error()); }
  finally { CloseHandle(h); }
 }
}
"@
$root = Split-Path $PSScriptRoot -Parent
$dart = (Get-Command dart).Source
$file = Join-Path $env:TEMP ("editable-probe-" + [guid]::NewGuid() + '.txt')
$redirect = if ($Scenario -eq 'redirected') { "2> '$file.stderr'" } else { '' }
$term = if ($Scenario -like 'dumb-*') { "`$env:TERM='dumb';" } else { "" }
$appScenario = if ($PublicApi) { "public-$Scenario" } else { $Scenario }
$routeName = if ($PublicApi) { 'public' } else { 'compatibility' }
$line = "$term Set-Location '$root'; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.ready');`$childWait++){ Start-Sleep -Milliseconds 50 }; if(!(Test-Path '$file.ready')){ exit 3 }; & '$dart' run test/text_input_native_app.dart $appScenario '$file.trigger' $redirect > '$file'; Set-Content '$file.dart-exitcode' `$LASTEXITCODE; Set-Content '$file.done' done; for(`$childWait=0;`$childWait -lt 600 -and !(Test-Path '$file.release');`$childWait++){ Start-Sleep -Milliseconds 50 }"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($line))
$reportParent = Split-Path $Report -Parent
if([string]::IsNullOrEmpty($reportParent)) { $reportParent = $env:TEMP }
$artifactDirectory = Join-Path $reportParent ("text-input-$routeName-$Scenario-" + [guid]::NewGuid().ToString('n'))
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$phase = 'setup'
$phaseStarted = $stopwatch.Elapsed
$before=''
$during=''
$after=''
function Enter-ProbePhase([string]$Name) {
  $script:phase = $Name
  $script:phaseStarted = $script:stopwatch.Elapsed
}
function Read-ProbeFileText([string]$Path) {
  if(!(Test-Path -LiteralPath $Path)) { return $null }
  try { return [System.IO.File]::ReadAllText($Path) } catch { return "unavailable: $($_.Exception.Message)" }
}
function Write-TextInputFailureArtifacts([string]$ErrorMessage) {
  New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
  $transcript = ''
  try { $transcript = [NativeProbe]::ScreenText() } catch { $transcript = "unavailable: $($_.Exception.Message)" }
  $transcriptPath = Join-Path $artifactDirectory 'terminal-transcript.txt'
  [System.IO.File]::WriteAllText($transcriptPath,$transcript)
  $editorState = ''
  try { $editorState = [NativeProbe]::EditorState() } catch { $editorState = "unavailable: $($_.Exception.Message)" }
  $processId = $null; $processExited = $false; $hasExitCode = $false; $exitCode = $null
  if($p) {
    $processId = $p.Id
    try { $processExited = $p.HasExited } catch {}
    if($processExited) {
      try { $exitCode = $p.ExitCode; $hasExitCode = $true } catch {}
    }
  }
  $elapsed = $stopwatch.Elapsed.TotalMilliseconds
  $phaseElapsed = ($stopwatch.Elapsed - $phaseStarted).TotalMilliseconds
  $resultText = Read-ProbeFileText $file
  $stderrText = Read-ProbeFileText "$file.stderr"
  $dartExitText = Read-ProbeFileText "$file.dart-exitcode"
  $dartExitCode = $null
  if($null -ne $dartExitText) { $parsed = 0; if([int]::TryParse($dartExitText.Trim(),[ref]$parsed)) { $dartExitCode = $parsed } }
  $cleanupMetadata = $null
  if($definition -and $definition.ContainsKey('Cleanup')) { $cleanupMetadata = $definition.Cleanup }
  $diagnostic = [ordered]@{
    scenario = $Scenario
    route = $routeName
    behavior = $Scenario
    phase = $phase
    elapsedMilliseconds = $elapsed
    phaseElapsedMilliseconds = $phaseElapsed
    childExitStatus = [ordered]@{
      processId = $processId
      processExited = $processExited
      hasExitCode = $hasExitCode
      exitCode = $exitCode
      dartExitCode = $dartExitCode
      dartExitCodeFilePresent = (Test-Path -LiteralPath "$file.dart-exitcode")
    }
    consoleStates = [ordered]@{ before = $before; during = $during; after = $after; editor = $editorState }
    resultFile = $file
    resultFilePresent = (Test-Path -LiteralPath $file)
    resultFileContent = $resultText
    stderrFile = "$file.stderr"
    stderrFilePresent = (Test-Path -LiteralPath "$file.stderr")
    stderrFileContent = $stderrText
    triggerFilePresent = (Test-Path -LiteralPath "$file.trigger")
    doneFilePresent = (Test-Path -LiteralPath "$file.done")
    cleanup = $cleanupMetadata
    artifactDirectory = $artifactDirectory
    transcriptFile = $transcriptPath
    error = $ErrorMessage
  }
  [System.IO.File]::WriteAllText((Join-Path $artifactDirectory 'diagnostic.json'),($diagnostic | ConvertTo-Json -Depth 8))
  $summary = @(
    "scenario=$Scenario",
    "route=$routeName",
    "phase=$phase",
    "elapsedMilliseconds=$elapsed",
    "phaseElapsedMilliseconds=$phaseElapsed",
    "processId=$processId",
    "processExited=$processExited",
    "exitCode=$exitCode",
    "dartExitCode=$dartExitCode",
    "resultFilePresent=$(Test-Path -LiteralPath $file)",
    "doneFilePresent=$(Test-Path -LiteralPath "$file.done")",
    "artifactDirectory=$artifactDirectory",
    "transcriptFile=$transcriptPath",
    "error=$ErrorMessage",
    '',
    '--- terminal transcript ---',
    $transcript
  )
  [System.IO.File]::WriteAllLines((Join-Path $artifactDirectory 'failure.txt'),$summary)
  return $artifactDirectory
}

# Bounded-waits for an observable console state instead of assuming a fixed
# post-key delay was enough; fails with the last observed state. Conditions
# resolve script-scope variables through the script's own scope chain.
function Wait-Probe([scriptblock]$read, [scriptblock]$ok, [string]$what) {
  $value = $null
  for($n=0;$n -lt 50;$n++){
    $value = & $read
    if(& $ok $value){return $value}
    Start-Sleep -Milliseconds 100
  }
  throw "timed out waiting for ${what}: $value"
}
function Wait-ProbeSettled([scriptblock]$read, [string]$what) {
  $last = & $read
  for($n=0;$n -lt 50;$n++){
    Start-Sleep -Milliseconds 100
    $current = & $read
    if($current -eq $last){return $current}
    $last = $current
  }
  throw "timed out waiting for ${what} to settle: $last"
}
# Table-driven scenario definitions keep the input driver, expected result and
# cleanup contract paired under one behavior name. Route differences are data
# (`ExpectedByRoute`), not a second classification switch.
$waitForAlphaPaint = {
 # Console mode acquisition precedes the first complete component paint. Key-only
 # scenarios are especially sensitive to that transition: wait for the editable
 # default to observably paint before injecting a control key.
 [void](Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^7:\d+:> alpha$'} 'the initial editable default paint')
}
$helpInput = {
 $isPassword=$Scenario.Contains('password')
 # Console mode acquisition precedes the first complete component paint.
 # Wait for the prompt itself before capturing any reference state; otherwise
 # a hidden secret prompt can be captured halfway through its opening frame.
 $promptLabel=if($isPassword){'Synthetic password'}else{'Name'}
 [void](Wait-Probe {[NativeProbe]::ScreenText()} {param($v) $v.Contains($promptLabel)} 'the opening prompt paint')
 if($isPassword){
  [NativeProbe]::Text('TrelisCanary7Q9')
 }else{
  [NativeProbe]::Key([char]0,0x25,0)
  # The hidden-entry path needs no visible echo gate because console input
  # records are ordered before F1. A visible text edit does: capturing the
  # pre-help caret before the Left key repaint would make the later exact
  # restoration comparison race the input pump rather than test the product.
  [void](Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^6:\d+:> alpha$'} 'the left-arrow caret state')
 }
 # Capture the quiesced pre-help state: a mistimed capture can only fail
 # the restoration comparison loudly, never pass it falsely.
 $editor=Wait-ProbeSettled {[NativeProbe]::EditorState()} 'the pre-help editor state'
 $screen=Wait-ProbeSettled {[NativeProbe]::ScreenText()} 'the pre-help screen'
 [NativeProbe]::Key([char]0,0x70,0)
 $help=Wait-Probe {[NativeProbe]::ScreenText()} {param($v) $v.Contains('Help:')} 'help to open'
 if($help.Contains('TrelisCanary7Q9')){throw 'help disclosed hidden entry'}
 # Reopening help must not nest screens or lose the original editor. The
 # ordinary text between the repeated F1 and Escape must remain modal noise:
 # submit outcomes below fail if any of it becomes answer data.
 [NativeProbe]::Key([char]0,0x70,0)
 [NativeProbe]::Text('ModalNoise9')
 [NativeProbe]::Key([char]27,27,0)
 # Console input records are processed in order, so the dismissal follows
 # both help keys and the modal noise; bounded-wait for the observable
 # restored screen and caret instead of assuming fixed post-key delays were
 # enough.
 $dismissed=Wait-Probe {[NativeProbe]::ScreenText()} {param($v) $v -eq $screen} 'the original screen to be restored'
 if($dismissed.Contains('Help:')){throw 'dismissed help remains on screen'}
 $restoredCaret=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -eq $editor} 'the editor caret to be restored'
 if($Scenario.Contains('interrupt')) {
  [NativeProbe]::Key([char]0,0x70,0)
  [NativeProbe]::Key([char]3,67,8)
 } elseif($Scenario.Contains('eof')) {
  [NativeProbe]::Key([char]0,0x70,0)
  [NativeProbe]::Key([char]26,90,8)
 } elseif($isPassword){[NativeProbe]::Text("`rsubmit`r")}else{[NativeProbe]::Text("X`r")}
}

$scenarioDefinitions = @{
 'linear-cursor' = @{
  Expected='alphXa'
  Cleanup='release-console-tree'
  Input={
   if([int]$parts[3] -eq 0){throw "active editor cursor is hidden: $during"}
   # Bounded-wait for the opening paint: console acquisition is observed
   # before the first frame reaches the screen, so a single read here can
   # otherwise race the paint and report an empty row instead of the prompt.
   $initial=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^7:([0-9]+):> alpha$'} 'the initial caret after the editable default'
   if($initial -notmatch '^7:([0-9]+):> alpha$'){throw "initial cursor is not after the editable default: $initial"}
   $row=$Matches[1]
   [NativeProbe]::Key([char]0,0x24,0)
   $atHome=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -eq "2:${row}:> alpha"} 'the Home caret state'
   [NativeProbe]::Key([char]0,0x23,0)
   $end=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -eq $initial} 'the End caret state'
   [NativeProbe]::Key([char]0,0x25,0)
   [NativeProbe]::Text('X')
   $edited=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -eq "7:${row}:> alphXa"} 'the insertion caret state'
   [NativeProbe]::Text("`r")
  }
 }
 'linear-long' = @{
  Expected=('0123456789' * 29) + '012345678X9'
  Cleanup='release-console-tree'
  Input={
   if([int]$parts[3] -eq 0){throw "active editor cursor is hidden: $during"}
   # Bounded-wait for the opening paint, as in linear-cursor: acquisition is
   # observed before the first frame, so an unbounded single read can race it.
   $initial=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^([0-9]+):([0-9]+):> <[0-9]+89$'} 'the clipped long default'
   if($initial -notmatch '^([0-9]+):([0-9]+):> <[0-9]+89$'){throw "long default is not clipped onto one editable line: $initial"}
   $row=$Matches[2]
   [NativeProbe]::Key([char]0,0x24,0)
   $atHome=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match "^2:${row}:> 0123456789[0-9]+>$"} 'the Home caret state'
   [NativeProbe]::Key([char]0,0x23,0)
   $end=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -eq $initial} 'the End caret state'
   [NativeProbe]::Key([char]0,0x25,0)
   [NativeProbe]::Text('X')
   $edited=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match "^[0-9]+:${row}:> <[0-9]+8X(?:9|>)$"} 'the insertion caret state'
   # The shared viewport reserves overflow-marker cells. The final 9 may
   # remain visible or be truthfully clipped; the accepted answer below must
   # still contain it. Both shapes must stay on the same editable row.
   if($edited -notmatch "^[0-9]+:${row}:> <[0-9]+8X(?:9|>)$"){throw "long-line insertion left stale or wrapped text: $edited"}
   [NativeProbe]::Text("`r")
  }
 }
 'repeat' = @{
  Expected='alpha,alpha'
  Cleanup='release-console-tree'
  Input={ if($PublicApi){[NativeProbe]::Text("`r`r`r")}else{[NativeProbe]::Text("`r`r")} }
 }
 'error' = @{ Expected='alpha'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("`r`r") } }
 'eof' = @{ Expected='eof'; Cleanup='release-console-tree'; Input={ & $waitForAlphaPaint; [NativeProbe]::Key([char]26,90,8) } }
 'escape' = @{ Expected='cancel'; Cleanup='release-console-tree'; Input={ & $waitForAlphaPaint; [NativeProbe]::Key([char]27,27,0) } }
 'concurrent' = @{ Expected='busy,alpha'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("`r") } }
 'resize' = @{
  Expected=('0123456789' * 6)
  Cleanup='restore-resize-then-release-console-tree'
  Input={
   # Wait for the opening paint instead of trusting a fixed startup delay, so a
   # cold compilation cannot be mistaken for a prompt that never appeared.
   $initial=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^[0-9]+:[0-9]+:> [0-9]+$'} 'the unwindowed long default'
   if($initial -notmatch '^[0-9]+:[0-9]+:> [0-9]+$'){throw "the long default is not one unwindowed draft row: $initial"}
   if([int]([NativeProbe]::State().Split(':')[3]) -eq 0){throw "active editor cursor is hidden"}
   [NativeProbe]::Resize(40,20)
   $reflowed=Wait-Probe {[NativeProbe]::EditorState()} {param($v) $v -match '^[0-9]+:[0-9]+:> <[0-9]+$'} 'the idle resize reflow'
   if($reflowed -notmatch '^[0-9]+:[0-9]+:> <[0-9]+$'){throw "an idle resize did not reflow the draft row: $reflowed"}
   $row=$reflowed.Substring($reflowed.IndexOf(':> ')+2)
   if($row.Length -gt 40){throw "the repaint ignored the new width ($($row.Length) cells): $reflowed"}
   [NativeProbe]::Text("`r")
  }
 }
 'rich' = @{ Expected='alpha'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("`r") } }
 'dumb-auto' = @{ Expected='alpha'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("`r") } }
 'dumb-rich' = @{
  ExpectedByRoute=@{
   'compatibility'='unavailable:Rich interaction unavailable on the selected output; use linear or automatic mode.'
   'public'='unavailable:Rich interaction is unavailable on the selected output.'
  }
  Cleanup='release-console-tree'
  Input={ }
 }
 'redirected' = @{ Expected='alpha'; Cleanup='retain-stderr-evidence-on-failure-release-console-tree'; Input={ [NativeProbe]::Text("`r") } }
 'stdout' = @{ Expected='alpha'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("`r") } }
 'session-retire' = @{
  Expected='retired'
  Cleanup='remove-trigger-release-console-tree'
  UsesTrigger=$true
  Input={ Set-Content -Path "$file.trigger" -Value 'go' }
 }
 'paste' = @{ Expected='/cancel'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("$([char]27)[200~/cancel$([char]27)[201~`r") } }
 'unicode' = @{ Expected='1f600'; Cleanup='release-console-tree'; Input={ [NativeProbe]::Text("$([char]::ConvertFromUtf32(0x1f600))`r") } }
 'interrupt' = @{ Expected='interrupt'; Cleanup='release-console-tree'; Input={ & $waitForAlphaPaint; [NativeProbe]::Key([char]3,67,8) } }
 'help-text-linear' = @{ Expected='alphXa'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
 'help-text-rich' = @{ Expected='alphXa'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
 'help-password-linear' = @{ Expected='accepted'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
 'help-password-rich' = @{ Expected='accepted'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
 'help-password-interrupt-linear' = @{ Expected='interrupt'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
 'help-text-eof-rich' = @{ Expected='eof'; Cleanup='verify-help-dismissed-release-console-tree'; IsModalHelp=$true; Input=$helpInput }
}
$definition = $null

$p = $null
try {
 if(!$scenarioDefinitions.ContainsKey($Scenario)){throw "Unknown scenario $Scenario"}
 $definition=$scenarioDefinitions[$Scenario]
 Enter-ProbePhase 'startup-attach'
 $p=Start-Process powershell.exe -WindowStyle Normal -ArgumentList '-NoProfile','-EncodedCommand',$encoded -PassThru
 # Console delegation/attachment is already bounded by the retry loop below;
 # the child does not launch Dart until the explicit ready handshake arrives.
 [void][NativeProbe]::FreeConsole()
 $attached=$false
 for($n=0;$n -lt 100 -and !$attached;$n++){ $attached=[NativeProbe]::AttachConsole($p.Id); if(!$attached){Start-Sleep -Milliseconds 100} }
 if(!$attached){throw 'AttachConsole failed'}
 # The Dart launcher itself enables VT output; preserve its normal console baseline.
 $before=[NativeProbe]::State()
 Set-Content -Path "$file.ready" -Value ready
 Enter-ProbePhase 'interaction-readiness'
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
 Enter-ProbePhase 'input-driving'
 & $definition.Input
 Enter-ProbePhase 'result-file'
 for($n=0;$n -lt 100;$n++){if((Test-Path $file) -and (Get-Item $file).Length -gt 0){break}; Start-Sleep -Milliseconds 100}

 Enter-ProbePhase 'process-exit'
 for($n=0;$n -lt 100 -and !(Test-Path "$file.done");$n++){Start-Sleep -Milliseconds 100}
 if (!(Test-Path "$file.done")) { throw "probe process did not exit" }
 $actual=(Get-Content $file -Raw).Trim()
 Enter-ProbePhase 'console-restoration'
 $after=''; for($n=0;$n -lt 100;$n++){ $after=[NativeProbe]::State(); if($after -eq $before){break}; Start-Sleep -Milliseconds 100 }
 if ($Scenario -eq 'stdout') {
  if ($actual.Contains([char]27) -or !$actual.Contains('Name')) { throw 'unstable stdout transcript' }
  $actual = ($actual -split "`r?`n")[-1]
 }
 Enter-ProbePhase 'result-comparison'
 if($definition.ContainsKey('ExpectedByRoute')) {
  $expected=$definition.ExpectedByRoute[$routeName]
 } else {
  $expected=$definition.Expected
 }
 if($definition.ContainsKey('IsModalHelp') -and $definition.IsModalHelp) {
  if([NativeProbe]::ScreenText().Contains('Help:')){throw 'help screen survived prompt exit'}
 }
 if($actual -ne $expected){throw "unexpected result: $actual"}
 if($Scenario -eq 'redirected') {
  $transcript = Get-Content "$file.stderr" -Raw
  if ($transcript.Contains([char]27) -or !$transcript.Contains('Name')) { throw 'unstable redirected output' }
 }
 if($before -ne $after){throw "console state changed: $before -> $after"}
 $pubMarker = " $routeName"
 Set-Content $Report "text input$pubMarker $Scenario PASS result=$actual state=$before -> $during -> $after"
} catch {
  $message = $_.Exception.Message
  $artifact = ''
  try { $artifact = Write-TextInputFailureArtifacts $message } catch { $artifact = "artifact-write-failed: $($_.Exception.Message)" }
  $childExit = 'unavailable'
  if($p -and $p.HasExited) { try { $childExit = [string]$p.ExitCode } catch {} }
  $elapsedMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds,1)
  Set-Content $Report "text input $routeName $Scenario FAIL phase=$phase elapsedMs=$elapsedMs childExit=$childExit artifact=$artifact error=$message"
  throw
}
finally {
 Set-Content -Path "$file.release" -Value release -ErrorAction SilentlyContinue; [void][NativeProbe]::FreeConsole(); if($p -and !$p.HasExited){ [void]$p.WaitForExit(1000) }; if($p -and !$p.HasExited){ & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null; if(!$p.WaitForExit(2000)){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue} }; Remove-Item $file,"$file.release","$file.ready","$file.done","$file.dart-exitcode","$file.stderr","$file.trigger" -Force -ErrorAction SilentlyContinue }
