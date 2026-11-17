# Ticket 01 evidence: PlainTheme factories and independent colour themes

**Status:** resolved
**Source revision:** `HEAD` on `ticket/theme-01-plain-palettes`
**Integration base:** `af79b49dbefd803578c48484b7df8b65168073d4`
**Environment:** Windows 11, Dart SDK (stable), local worktree `C:\Users\bvlou\projects\prompty-theme-01`

## What was built

- `lib/src/color_theme_palettes.g.dart`: 45 named immutable palettes generated
  from `example/prototype-themes/generate.py` plus `ColorThemes.terminalDefault`.
- `lib/src/themes/plain_theme.dart`: `PlainTheme` static factory namespace with
  all 38 typed component factories.
- Constructor presentation parameters (`colors`, `instructions`,
  `supplementaryHelp`) added to every interactive component that was missing
  them, and `colors` added to feedback components.
- Palette-aware rendering wired into `Password`, `URLInput`, `Multiline`,
  `Keypress`/`KeyChordInput`, and feedback (`Progress`, `Spinner`,
  `MultiSpinner`, `Text`).
- `lib/prompty.dart` exports the new theme namespace.
- `example/plain_theme_example.dart`: public usage example.
- Tests:
  - `test/color_themes_test.dart` (7 tests)
  - `test/plain_theme_factories_test.dart` (17 tests)
  - `test/plain_theme_lifecycle_test.dart` (6 tests)
  - `test/plain_theme_acceptance_matrix_test.dart` (rich/linear matrix)
  - `test/plain_theme_color_application_test.dart` (palette-in-output)
  - `test/public_compatibility_inventory_test.dart` updated for the new export.

## Verification results

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format .` then `--output=none --set-exit-if-changed` | 0 changed |
| Static analysis | `dart analyze` | No issues found |
| Focused verification | `dart test test/plain_theme_acceptance_matrix_test.dart test/plain_theme_color_application_test.dart test/plain_theme_factories_test.dart test/plain_theme_lifecycle_test.dart test/color_themes_test.dart test/public_compatibility_inventory_test.dart test/feedback_test.dart` | +140, all passed |
| Issue-tracker boundary | `dart run tool/check_issue_tracker.dart` | No legacy tracker |

## Palette mapping check

`test/color_themes_test.dart` asserts the Signal palette maps atlas tokens to
semantic roles:

- `text` → `foreground`
- `terminal` → `background`
- `muted` → `muted`
- `accent` → `accent` and `selectionBackground`
- `selected` → `selectionForeground`
- `success` → `success`
- `error` → `error`
- `rule` → `border`
- missing atlas `warning` → `accent` (overridable via `copyWith`)
- atlas `page` colour is ignored (background uses terminal surface)

## Factory surface check

`test/plain_theme_factories_test.dart` constructs every `PlainTheme.<component>`
with distinguishable non-default `colors`, `instructions` and
`supplementaryHelp` arguments and asserts the returned object is the correct
concrete type with the expected configuration.

## Lifecycle check

`test/plain_theme_lifecycle_test.dart` exercises:

- `PlainTheme.textInput` in linear and rich modes (synthetic geometry)
- `PlainTheme.confirm` linear default acceptance
- `PlainTheme.select` linear choice acceptance
- `PlainTheme.progress` standalone start/update/finish
- `PlainTheme.text.present` with a colour theme

`test/plain_theme_acceptance_matrix_test.dart` exercises every applicable
`PlainTheme.*` factory through rich and linear prompt lifecycles using the
existing `ScriptedInput` acceptance helper, covering supplied-answer paths,
choice components, and feedback tasks.

## Colour-application check

`test/plain_theme_color_application_test.dart` asserts that non-default
palettes produce ANSI-styled output for `Text`, `Progress`, `Spinner`,
`MultiSpinner`, `Password`, `URLInput`, `Multiline`, and key capture, while
`ColorThemes.terminalDefault` remains unstyled.

## Limitations and remaining work

- **No cross-structure palette integration tests** (those belong to later
  theme tickets once more structural classes are added).
- **No NO_COLOR/redirected-output fixture specifically for PlainTheme**
  beyond the existing backend tests.

## Conclusion

The foundational PlainTheme factory surface, the 45 named palettes, value
equality, full rich/linear lifecycle matrix, per-component colour wiring,
colour-application tests, public example, and compatibility inventory are
implemented and pass all automated checks. The ticket is **resolved** and the
worktree is ready for merger.
