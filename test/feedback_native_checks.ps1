$ErrorActionPreference = 'Stop'
$probe = Join-Path $PSScriptRoot 'feedback_windows.ps1'
foreach ($scenario in @('rich', 'linear')) {
  $report = Join-Path $env:TEMP ("feedback-probe-" + [guid]::NewGuid() + '.txt')
  try {
    $process = Start-Process powershell.exe -PassThru -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$probe`"",
      '-Scenario', $scenario, '-Report', "`"$report`""
    )
    if (!$process.WaitForExit(30000)) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw "$scenario feedback probe timed out"
    }
    if (!(Test-Path $report)) { throw "$scenario feedback probe produced no report" }
    $result = (Get-Content $report -Raw).Trim()
    if ($process.ExitCode -ne 0 -or $result -notmatch "^feedback native $scenario narrow console PASS ") {
      throw "$scenario feedback probe failed: $result (exit $($process.ExitCode))"
    }
    Write-Output $result
  } finally {
    Remove-Item $report -Force -ErrorAction SilentlyContinue
  }
}
