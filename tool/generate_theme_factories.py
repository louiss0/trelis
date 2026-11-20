import re
import subprocess
import sys

with open('lib/src/themes/plain_theme.dart', 'r', encoding='utf-8') as f:
    source = f.read()

structure = sys.argv[1]
name = structure.capitalize() + 'Theme'
result = source.replace('PlainTheme', name)
result = result.replace(
    'Plain-theme factory namespace.',
    f'{structure.capitalize()}-theme factory namespace.\n///\n/// Components created through these factories are configured with [PromptStructure.{structure}].',
)
if structure != 'plain':
    result = result.replace(
        "import 'package:trelis/src/feedback.dart';\n",
        "import 'package:trelis/src/feedback.dart';\n"
        "import 'package:trelis/src/prompt_structure.dart';\n",
    )
# Add structure forwarding before every `colors: colors,` in a forwarding call.
result = re.sub(
    r"(\n    colors: colors,\n)",
    f"\n    structure: PromptStructure.{structure},"
    "\\1",
    result,
)
# Feedback factories forward structure on one line.
result = re.sub(
    r", colors: colors\)",
    f", colors: colors, structure: PromptStructure.{structure})",
    result,
)

out_path = f'lib/src/themes/{structure}_theme.dart'
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(result)

subprocess.run(
    ['dart', 'format', out_path],
    check=True,
    stdout=subprocess.DEVNULL,
)
print(f'generated {out_path}')
