# Ticket 07 — narrow TextInput viewport evidence

- **Status:** pass for the scripted public TextInput rendering/interaction coverage in this ticket.
- **Source revision:** `eb19e88c662cfe9a04fc4475f883abbea9361117` (`feat: viewport narrow TextInput rendering`), based on integration revision `c12ac24`.
- **Date/environment:** 2026-03-10; Windows host, Dart SDK selected by this checkout (`dart` on PATH). The scenarios use `ScriptedInput` with an explicit rich output profile and synthetic positive geometry; no physical terminal/font claim is made.

## Scenarios and results

`test/text_input_test.dart` adds public `TextInput.prompt` scenarios rather than measurement-helper tests:

1. A ten-column rich profile starts with a Unicode default, moves the real caret into the middle, edits it, and submits. The accepted answer is `ab中cdeZfgh`; the recorded terminal output has truthful left and right clipping indicators during the middle viewport.
2. A ten-column rich profile wraps a long protected label, instructions, and a validation message. A bidi control is displayed as the safe `\u{202E}` substitution, which is retained as one display unit rather than being wrapped through the substitution spelling.

The implementation reserves structural `> ` chrome and overflow-marker cells, adds only whole `TextDisplayMap` graphemes around the logical caret, and caps declared total width at 120 columns. Read-only content is wrapped under the same declared width. The README documents the cap and the non-splitting policy.

## Commands actually run

| Command | Result |
| --- | --- |
| `dart test test/text_input_test.dart --name "narrow rich" -r expanded` | Initial red run failed as expected before viewport geometry was threaded into the public renderer. |
| `dart test test/text_input_test.dart -r expanded` | Pass: 25 tests. |
| `dart analyze` | Pass: `No issues found!` |
| `dart test --reporter expanded` | Pass: 671 tests, `All tests passed!` |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/text_input_test.dart` | Pass. |

## Limitations

These are deterministic synthetic-profile rendering checks. They do not establish native terminal wrapping, terminal-specific emoji-cell behavior, resize notifications while idle, or visible GUI accessibility. Those requirements remain for their dedicated native/resize/platform evidence tickets.
