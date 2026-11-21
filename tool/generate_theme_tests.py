import re
import sys

theme = sys.argv[1]
name = theme.capitalize() + 'Theme'

for suffix in ['factories', 'acceptance_matrix']:
    with open(f'test/plain_theme_{suffix}_test.dart', 'r', encoding='utf-8') as f:
        source = f.read()

    result = source.replace('PlainTheme', name)
    result = result.replace('plain_theme', f'{theme}_theme')
    # Structural grammars may change the label's case, so generated
    # acceptance checks stay case-insensitive like the checked-in matrices.
    result = result.replace(
        "expect(out.toString(), contains('Name'));",
        "expect(out.toString().toLowerCase(), contains('name'));",
    )
    result = result.replace(
        "expect(out.toString(), contains('Notes'));",
        "expect(out.toString().toLowerCase(), contains('notes'));",
    )
    result = result.replace(
        "expect(out.toString(), contains('Decision'));",
        "expect(out.toString().toLowerCase(), contains('decision'));",
    )
    result = result.replace(
        "expect(out.toString(), contains('Choice'));",
        "expect(out.toString().toLowerCase(), contains('choice'));",
    )
    result = result.replace('PlainTheme component lifecycles', f'{name} component lifecycles')
    result = result.replace('PlainTheme typed factories', f'{name} typed factories')

    # Add structure assertion after colors assertion in factory tests.
    if suffix == 'factories':
        result = re.sub(
            r"(expect\(input\.colors, customColors\);\n)",
            r"\1      expect(input.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(confirm\.colors, customColors\);\n)",
            r"\1      expect(confirm.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(select\.colors, customColors\);\n)",
            r"\1      expect(select.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(slider\.colors, customColors\);\n)",
            r"\1      expect(slider.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(tree\.colors, customColors\);\n)",
            r"\1      expect(tree.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(time\.colors, customColors\);\n)",
            r"\1      expect(time.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(autocomplete\.colors, customColors\);\n)",
            r"\1      expect(autocomplete.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(masked\.colors, customColors\);\n)",
            r"\1      expect(masked.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(number\.colors, customColors\);\n)",
            r"\1      expect(number.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(port\.colors, customColors\);\n)",
            r"\1      expect(port.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(url\.colors, customColors\);\n)",
            r"\1      expect(url.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(color\.colors, customColors\);\n)",
            r"\1      expect(color.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(cron\.colors, customColors\);\n)",
            r"\1      expect(cron.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(path\.colors, customColors\);\n)",
            r"\1      expect(path.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(key\.colors, customColors\);\n)",
            r"\1      expect(key.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(duration\.colors, customColors\);\n)",
            r"\1      expect(duration.structure, PromptStructure." + theme + r");\n",
            result,
        )
        result = re.sub(
            r"(expect\(date\.colors, customColors\);\n)",
            r"\1      expect(date.structure, PromptStructure." + theme + r");\n",
            result,
        )

    out_path = f'test/{theme}_theme_{suffix}_test.dart'
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f'generated {out_path}')
