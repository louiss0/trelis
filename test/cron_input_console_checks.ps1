$ErrorActionPreference = 'Stop'
$probe = Join-Path $PSScriptRoot 'cron_input_windows.ps1'
foreach ($scenario in @('rich', 'linear', 'rich-cancel', 'linear-cancel')) {
    $report = Join-Path $env:TEMP ("cron-console-probe-" + [guid]::NewGuid() + '.txt')
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
      if ($process.ExitCode -ne 0 -or $result -notmatch '^cron input (rich|linear)(-cancel)? PASS ') {
        throw "$scenario probe failed: $result (exit $($process.ExitCode))"
      }
      Write-Output $result
    } finally {
      Remove-Item $report -Force -ErrorAction SilentlyContinue
    }
}

