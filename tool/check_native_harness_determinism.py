"""Static guardrails for Windows native PowerShell harness determinism.

Fixed second-scale sleeps in these harnesses historically hid two different
things: console delegation/compilation startup and the lifetime needed for the
outer probe to inspect or restore the console. Those phases must instead be
coordinated through explicit readiness/release handshakes or bounded observable
polling. Millisecond sleeps inside bounded polling loops are the polling
interval, not a consequential fixed delay, and are allowed.
"""

import re
import sys
from pathlib import Path

ROOT = Path.cwd()
TEST = ROOT / 'test'

# Native PowerShell probes live directly under test/. The Python/POSIX and
# Dart harnesses have their own readiness mechanisms and are outside this
# Windows-specific scan.
HARNESS_PATTERNS = ('*_windows.ps1', '*_native_checks.ps1')

fixed_sleep = re.compile(r'Start-Sleep\s+-Seconds\b')
failures = []
for pattern in HARNESS_PATTERNS:
    for path in sorted(TEST.glob(pattern)):
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            if fixed_sleep.search(line):
                failures.append(f'{path.relative_to(ROOT)}:{number}: consequential fixed sleep: {line.strip()}')

if failures:
    print('native harness determinism check failed:')
    print('\n'.join(failures))
    sys.exit(1)

print('native harness determinism check: ok')
