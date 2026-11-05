$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$key = 'HKCU:\Control Panel\International'
$names = @('sDecimal', 'sThousand', 'sGrouping', 'sNegativeSign', 'iNeg')
$original = @{}
foreach ($name in $names) {
  $original[$name] = (Get-ItemProperty $key).$name
}
try {
  Set-ItemProperty $key sDecimal ','
  Set-ItemProperty $key sThousand '.'
  Set-ItemProperty $key sGrouping '3;0'
  Set-ItemProperty $key sNegativeSign '-'
  Set-ItemProperty $key iNeg '1'
  $overridden = (& dart run test/number_input_native_app.dart resolve '1.234,5').Trim()
  if ($LASTEXITCODE -ne 0 -or $overridden -ne '12345:1') {
    throw "effective user override was not applied: $overridden"
  }
  $report = Join-Path $env:TEMP ("number-preference-probe-" + [guid]::NewGuid() + '.txt')
  try {
    $process = Start-Process powershell.exe -PassThru -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
      "`"$(Join-Path $PSScriptRoot 'number_input_windows.ps1')`"",
      '-Scenario', 'system-rich', '-Target', 'system-change',
      '-Report', "`"$report`""
    )
    if (!$process.WaitForExit(40000)) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw 'mid-prompt preference-change probe timed out'
    }
    if (!(Test-Path $report)) { throw 'preference-change probe produced no report' }
    $result = (Get-Content $report -Raw).Trim()
    if ($process.ExitCode -ne 0 -or $result -notmatch '^number input system-rich PASS ') {
      throw "preference-change probe failed: $result (exit $($process.ExitCode))"
    }
  } finally {
    Remove-Item $report -Force -ErrorAction SilentlyContinue
  }
  $changed = (& dart run test/number_input_native_app.dart resolve '1:234;5').Trim()
  if ($LASTEXITCODE -ne 0 -or $changed -ne '12345:1') {
    throw "next prompt did not use changed preferences: $changed"
  }
  Write-Output "number native preferences PASS override=$overridden stable-draft=1.234,5 next=$changed"
} finally {
  foreach ($name in $names) {
    Set-ItemProperty $key $name $original[$name]
  }
}
