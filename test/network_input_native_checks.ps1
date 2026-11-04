$ErrorActionPreference = 'Stop'
$probe = Join-Path $PSScriptRoot 'network_input_windows.ps1'
foreach ($target in @('port', 'ip')) {
  foreach ($scenario in @('rich', 'linear')) {
    $report = Join-Path $env:TEMP ("network-probe-" + [guid]::NewGuid() + '.txt')
    try {
      $process = Start-Process powershell.exe -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$probe`"",
        '-Scenario', $scenario, '-Target', $target, '-Report', "`"$report`""
      )
      if (!$process.WaitForExit(30000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "$target $scenario probe timed out"
      }
      if (!(Test-Path $report)) { throw "$target $scenario probe produced no report" }
      $result = (Get-Content $report -Raw).Trim()
      if ($process.ExitCode -ne 0 -or $result -notmatch '^network input (port|ip) (rich|linear) PASS ') {
        throw "$target $scenario probe failed: $result (exit $($process.ExitCode))"
      }
      Write-Output $result
    } finally {
      Remove-Item $report -Force -ErrorAction SilentlyContinue
    }
  }
}
