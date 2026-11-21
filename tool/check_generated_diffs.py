"""Verify checked-in generated theme sources match their generators.

The current files are copied aside, generators are rerun, outputs are compared
byte for byte, and the originals are restored on mismatch so a failed check
does not silently rewrite the worktree.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

THEMES = [
    'rail', 'ascii', 'double', 'chevron', 'colon', 'box', 'bracket', 'block',
    'branch', 'round', 'line', 'minimal', 'form', 'ledger',
]

root = Path.cwd()
targets = [root / 'lib/src/themes/plain_theme.dart']
for theme in THEMES:
    targets.append(root / f'lib/src/themes/{theme}_theme.dart')
    targets.append(root / f'test/{theme}_theme_factories_test.dart')
    targets.append(root / f'test/{theme}_theme_acceptance_matrix_test.dart')

with tempfile.TemporaryDirectory() as scratch:
    backups = {}
    for target in targets:
        backup = Path(scratch) / target.name
        shutil.copy2(target, backup)
        backups[target] = backup

    failed = False
    try:
        for theme in THEMES:
            for generator in ['generate_theme_factories.py',
                              'generate_theme_tests.py']:
                subprocess.run(
                    [sys.executable, f'tool/{generator}', theme],
                    check=True,
                    stdout=subprocess.DEVNULL,
                )
        for target, backup in backups.items():
            if target.read_bytes() != backup.read_bytes():
                print(f'generated diff: {target.relative_to(root)}')
                failed = True
    finally:
        for target, backup in backups.items():
            shutil.copy2(backup, target)

if failed:
    sys.exit('generated files are out of date')
print(f'generated diff check: ok ({len(targets)} targets)')
