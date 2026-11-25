"""Generate structural theme tests from the Plain templates.

`factories` is the public instance API template; `acceptance_matrix` remains a
component-level tracer that exercises each structure through the internal
compatibility seam. Neither target may be edited by hand.
"""

import subprocess
import sys

from lf_output import enforce_lf, write_lf

theme = sys.argv[1]
name = theme.capitalize() + 'Theme'

for suffix in ['factories', 'acceptance_matrix']:
    with open(f'test/plain_theme_{suffix}_test.dart', 'r', encoding='utf-8') as f:
        source = f.read()

    result = source.replace('PlainTheme', name)
    result = result.replace('plain_theme', f'{theme}_theme')
    result = result.replace('PromptStructure.plain', f'PromptStructure.{theme}')
    result = result.replace('PlainTheme component lifecycles',
                            f'{name} component lifecycles')
    result = result.replace('PlainTheme typed factories',
                            f'{name} typed factories')

    if suffix == 'acceptance_matrix':
        # Structural grammars may change the label's case, so generated
        # acceptance checks stay case-insensitive like the checked-in matrices.
        for label in ['Name', 'Notes', 'Decision', 'Choice']:
            result = result.replace(
                f"expect(out.toString(), contains('{label}'));",
                f"expect(out.toString().toLowerCase(), "
                f"contains('{label.lower()}'));",
            )

    out_path = f'test/{theme}_theme_{suffix}_test.dart'
    write_lf(out_path, result)

    subprocess.run(['dart', 'format', out_path], check=True,
                   stdout=subprocess.DEVNULL)
    # The formatter preserves the file's existing line endings, so the LF
    # policy is enforced again after formatting rather than assumed.
    enforce_lf(out_path)
    print(f'generated {out_path}')
