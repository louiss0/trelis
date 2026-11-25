"""Generate structural theme instances from the Plain template.

Every non-plain `lib/src/themes/<slug>_theme.dart` is generated. The template
carries the public instance methods; a structural theme only supplies its
structure and authored light/dark palette defaults.
"""

import subprocess
import sys

from lf_output import enforce_lf, write_lf

with open('lib/src/themes/plain_theme.dart', 'r', encoding='utf-8') as f:
    source = f.read()

structure = sys.argv[1]
name = structure.capitalize() + 'Theme'
result = source.replace('PlainTheme', name)
result = result.replace('PromptStructure.plain', f'PromptStructure.{structure}')

# Authored defaults and the library that declares them. The expression is
# placed in the template's `palettes:` slot.
palettes = {
    'rail': (
        "import 'package:trelis/src/rail_ink_blue_theme.dart' "
        "show RailAdaptivePalettes;",
        'ThemePaletteDefaults(light: RailAdaptivePalettes.light, '
        'dark: RailAdaptivePalettes.dark)',
    ),
    'ascii': (
        "import 'package:trelis/src/ascii_ink_blue_theme.dart' "
        "show AsciiAdaptivePalettes;",
        'ThemePaletteDefaults(light: AsciiAdaptivePalettes.light, '
        'dark: AsciiAdaptivePalettes.dark)',
    ),
    'double': (
        "import 'package:trelis/src/themes/double_theme_internal.dart' "
        "show DoublePaletteDefaults;",
        'ThemePaletteDefaults(light: DoublePaletteDefaults.light, '
        'dark: DoublePaletteDefaults.dark)',
    ),
    'chevron': (
        "import 'package:trelis/src/themes/chevron_theme_internal.dart' "
        "show ChevronPaletteDefaults;",
        'ThemePaletteDefaults(light: ChevronPaletteDefaults.light, '
        'dark: ChevronPaletteDefaults.dark)',
    ),
    'colon': (
        "import 'package:trelis/src/themes/colon_theme_internal.dart' "
        "show ColonPaletteDefaults;",
        'ThemePaletteDefaults(light: ColonPaletteDefaults.light, '
        'dark: ColonPaletteDefaults.dark)',
    ),
    'box': (
        "import 'package:trelis/src/structural_theme_palettes.dart' "
        "show StructuralThemePalettes;",
        'StructuralThemePalettes.box.defaults',
    ),
    'bracket': (
        "import 'package:trelis/src/themes/bracket_theme_internal.dart' "
        "show BracketPaletteDefaults;",
        'ThemePaletteDefaults(light: BracketPaletteDefaults.light, '
        'dark: BracketPaletteDefaults.dark)',
    ),
    'block': (
        "import 'package:trelis/src/block_theme_presentation.dart' "
        "show BlockAdaptivePalettes;",
        'ThemePaletteDefaults(light: BlockAdaptivePalettes.light, '
        'dark: BlockAdaptivePalettes.dark)',
    ),
    'branch': (
        "import 'package:trelis/src/themes/branch_presentation.dart' "
        "show BranchPresentation;",
        'BranchPresentation.defaults',
    ),
    'round': (
        "import 'package:trelis/src/themes/round_presentation.dart' "
        "show RoundPresentation;",
        'ThemePaletteDefaults(light: RoundPresentation.lightDefault, '
        'dark: RoundPresentation.darkDefault)',
    ),
    'line': (
        "import 'package:trelis/src/themes/line_presentation.dart' "
        "show LinePresentation;",
        'ThemePaletteDefaults(light: LinePresentation.lightDefault, '
        'dark: LinePresentation.darkDefault)',
    ),
    'minimal': (
        "import 'package:trelis/src/themes/minimal_presentation.dart' "
        "show MinimalPresentation;",
        'ThemePaletteDefaults(light: MinimalPresentation.lightDefault, '
        'dark: MinimalPresentation.darkDefault)',
    ),
    'form': (
        "import 'package:trelis/src/themes/form_presentation.dart' "
        "show FormPresentation;",
        'ThemePaletteDefaults(light: FormPresentation.lightDefault, '
        'dark: FormPresentation.darkDefault)',
    ),
    'ledger': (
        "import 'package:trelis/src/ledger_adaptive_theme.dart' "
        "show LedgerAdaptivePalettes;",
        'ThemePaletteDefaults(light: LedgerAdaptivePalettes.light, '
        'dark: LedgerAdaptivePalettes.dark)',
    ),
}

if structure != 'plain':
    extra_import, palette = palettes[structure]
    lines = result.splitlines()
    insert = next(
        index
        for index, line in enumerate(lines)
        if line.startswith('/// ')
    )
    lines.insert(insert, extra_import)
    result = '\n'.join(lines) + '\n'
    old = """ThemePaletteDefaults(
           light: PlainSepiaPalettes.light,
           dark: PlainSepiaPalettes.dark,
         )"""
    if old not in result:
        raise SystemExit('palette template slot not found in plain_theme.dart')
    result = result.replace(old, palette)
    result = result.replace(
        "import 'package:trelis/src/themes/plain_sepia_palettes.dart'\n"
        '    show PlainSepiaPalettes;\n',
        '',
    )
    if 'ThemePaletteDefaults' not in palette:
        result = result.replace(
            "import 'package:trelis/src/color_resolution.dart' "
            'show ThemePaletteDefaults;\n',
            '',
        )
    result = result.replace(
        '/// Plain structural theme instance.',
        f'/// {structure.capitalize()} structural theme instance.',
    )

out_path = f'lib/src/themes/{structure}_theme.dart'
write_lf(out_path, result)

subprocess.run(['dart', 'format', out_path], check=True, stdout=subprocess.DEVNULL)
# The formatter preserves the file's existing line endings, so the LF policy
# is enforced again after formatting rather than assumed from the host.
enforce_lf(out_path)
print(f'generated {out_path}')
