import sys

def edit(path, pairs, add_import=True):
    s = open(path, encoding='utf-8').read()
    if add_import and 'support/bounded_wait.dart' not in s:
        anchor = "import 'package:test/test.dart';\n"
        assert anchor in s, path
        s = s.replace(anchor, anchor + "\nimport 'support/bounded_wait.dart';\n", 1)
    for old, new in pairs:
        assert old in s, f'{path}: missing: {old[:80]}'
        s = s.replace(old, new)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('ok', path)

# --- cron_interaction_conformance_test.dart ---
p = 'test/cron_interaction_conformance_test.dart'
s = open(p, encoding='utf-8').read()
anchor = "import 'package:test/test.dart';\n"
s = s.replace(anchor, anchor + "\nimport 'support/bounded_wait.dart';\n", 1)

# Pattern A: fixed sleep then expect 'Calculating preview'
s = s.replace(
    "    await Future<void>.delayed(const Duration(milliseconds: 40));\n    expect(output.toString(), contains('Calculating preview'));",
    "    await awaitOutputContains(output, 'Calculating preview');",
)
s = s.replace(
    "      await Future<void>.delayed(const Duration(milliseconds: 40));\n      expect(output.toString(), contains('Calculating preview'));",
    "      await awaitOutputContains(output, 'Calculating preview');",
)
# Pattern B: fixed sleep then expect 'Matching preview: cancelled'
s = s.replace(
    "      await Future<void>.delayed(const Duration(milliseconds: 100));\n      expect(output.toString(), contains('Matching preview: cancelled'));",
    "      await awaitOutputContains(output, 'Matching preview: cancelled');",
)
s = s.replace(
    "    await Future<void>.delayed(const Duration(milliseconds: 100));\n    expect(output.toString(), contains('Matching preview: cancelled'));",
    "    await awaitOutputContains(output, 'Matching preview: cancelled');",
)
s = s.replace(
    "      await Future<void>.delayed(const Duration(milliseconds: 150));\n      expect(output.toString(), contains('Matching preview: cancelled'));",
    "      await awaitOutputContains(output, 'Matching preview: cancelled');",
)
open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok', p)

# --- cron_linear_parity_test.dart ---
p = 'test/cron_linear_parity_test.dart'
s = open(p, encoding='utf-8').read()
s = s.replace(anchor, anchor + "\nimport 'support/bounded_wait.dart';\n", 1)
s = s.replace(
    "        await Future<void>.delayed(const Duration(milliseconds: 60));\n        expect(output.toString(), contains('Calculating preview'));",
    "        await awaitOutputContains(output, 'Calculating preview');",
)
s = s.replace(
    "        await Future<void>.delayed(const Duration(milliseconds: 150));\n        expect(output.toString(), contains('Matching preview: cancelled'));",
    "        await awaitOutputContains(output, 'Matching preview: cancelled');",
)
# The 20ms sleep after the stray arrow key only separated ordered stream
# events; stream processing is in-order, so drain the event queue instead.
s = s.replace(
    "        input.add('\\x1b[A');\n        await Future<void>.delayed(const Duration(milliseconds: 20));",
    "        input.add('\\x1b[A');\n        await pumpEventQueue();",
)
open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok', p)
