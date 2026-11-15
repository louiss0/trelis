# Ticket 01 evidence: PlainTheme factories and independent colour themes

**Status:** claimed (implementation in progress)
**Source revision:** `4aff95e` on `ticket/theme-01-plain-palettes`
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
- `lib/prompty.dart` exports the new theme namespace.
- `example/plain_theme_example.dart`: public usage example.
- Tests:
  - `test/color_themes_test.dart` (7 tests)
  - `test/plain_theme_factories_test.dart` (17 tests)
  - `test/plain_theme_lifecycle_test.dart` (6 tests)
  - `test/public_compatibility_inventory_test.dart` updated for the new export.

## Verification results

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed .` | 0 changed |
| Static analysis | `dart analyze` | No issues found |
| Full suite | `dart test --reporter expanded` | +991, all passed |
| Issue-tracker boundary | `dart run tool/check_issue_tracker.dart` | No legacy tracker |
| New tests | `dart test test/color_themes_test.dart test/plain_theme_factories_test.dart test/plain_theme_lifecycle_test.dart` | 30 passed |
| Public inventory | `dart test test/public_compatibility_inventory_test.dart` | 8 passed |

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

## Limitations and remaining work

- **Not every component lifecycle is exercised.** The ticket asks to exercise
  every applicable Plain component task/lifecycle in rich and linear output.
  Only representative components are covered; full coverage of all 38
  components in both modes is not yet implemented.
- **Rendering colour wiring is partial.** The new `colors`/`instructions`
  fields are stored and forwarded, but several components (Password, URLInput,
  Multiline, key capture, feedback) do not yet apply the palette to their
  visible output beyond the existing TextInput/Select colour support.
- **No cross-structure palette integration tests** (those belong to later
  theme tickets once more structural classes are added).
- **No NO_COLOR/redirected-output fixture specifically for PlainTheme**
  beyond the existing backend tests.

## Conclusion

The foundational PlainTheme factory surface, the 45 named palettes, value
equality, and representative lifecycle tests are implemented and pass all
automated checks. Because full lifecycle coverage for every component and
complete colour wiring remain unfinished, the ticket is left **claimed** with
this evidence rather than resolved.
