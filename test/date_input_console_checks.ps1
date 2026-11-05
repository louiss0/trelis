$ErrorActionPreference = 'Stop'
$probe = Join-Path $PSScriptRoot 'date_input_windows.ps1'
foreach ($scenario in @('rich', 'linear')) {
    $report = Join-Path $env:TEMP ("date-console-probe-" + [guid]::NewGuid() + '.txt')
    try {
      $process = Start-Process powershell.exe -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$probe`"",
        '-Scenario', $scenario, '-Report', "`"$report`""
      )
      if (!$process.WaitForExit(30000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$scenario probe timed out"
      }
      if (!(Test-Path $report)) { throw "$scenario probe produced no report" }
      $result = (Get-Content $report -Raw).Trim()
      if ($process.ExitCode -ne 0 -or $result -notmatch '^date input (rich|linear) PASS ') {
        throw "$scenario probe failed: $result (exit $($process.ExitCode))"
      }
      Write-Output $result
    } finally {
      Remove-Item $report -Force -ErrorAction SilentlyContinue
    }
}
