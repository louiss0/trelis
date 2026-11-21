# 30 Migrate key capture prompts

Status: resolved

**Blocked by:** [09](09-state-and-compact-help.md)

**What to build:** Migrate Keypress and KeyChordInput through the theme-owned internal session and presentation seams while preserving existing public calls until cutover. Apply the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md); independently verify capture safety for this family.

## Proposed examples — NOT IMPLEMENTED

```dart
final key = RailTheme().keypress('Press a key');
final result = await key.prompt();
```

```dart
final chord = RailTheme().keyChordInput('Shortcut');
final first = await chord.prompt();
final again = await chord.prompt(); // Starts with configured initial state.
```

## Acceptance criteria

- [x] Test real Keypress and KeyChordInput components in rich, linear and screen-reader modes, preserving key/chord values, modifiers and existing capture semantics.
- [x] Display capture, validation and result states intelligibly with textual labels and independent indicators, including Unicode, ASCII, `NO_COLOR` and narrow layouts.
- [x] Show mandatory compact primary-action/help hints at rich bottom and after normal linear content; put essential screen-reader instructions before each prompt, even when instructions are hidden.
- [x] Provide and identify a component-safe help route that never steals a gesture intended for capture or reinterprets captured keys as help/cancel; test detailed help and preservation of in-progress capture state.
- [x] Independently test literal and special keys, chords, control sequences, escape/cancel behavior, paste handling where applicable, validation retries and cleanup without weakening capture safety.
- [x] Route capture and any delegates through theme-owned interaction, colors and input ownership, without a competing reader or a second external prompt; preserve availability checks.
- [x] Verify accepted, invalid/retry, cancelled, interrupted, unavailable and `InputEnded` outcomes, plus sequential reuse from configured initial state and concurrent prompt rejection.
- [x] Record automated tests and commands/results, and identify missing native-terminal and human screen-reader checks rather than claiming qualification.

## Comments

Added internal, non-exported `lib/src/theme_key_capture_components.dart` with
`ThemeKeyCapturePrompt.keypress` and `.keyChordInput`. Each instance captures
immutable configuration, joins one `ThemeSession` active period, resolves its
component colour override over the period's palette, and delegates to the real
components with only the session-owned reader and writer. Screen-reader periods
emit sequential essential instructions before the prompt; every completed
rich or linear prompt closes with the mandatory compact hint. Live feedback can
share the same period. No public constructor, factory, prompt signature or
export changed.

Validation before integration merge:

- `dart test test/theme_key_capture_components_test.dart test/key_capture_test.dart -r compact` — 46 passed.
- `dart format --output=none --set-exit-if-changed .` — 255 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5019 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.

Decisions: the shared `ComponentRoute.keyCapture` help route stays outside
armed capture; the real component keeps its Ctrl+T rich route and `/help`
linear route, while captured keys remain candidates. The themed seam adds a
compact footer after a completed prompt and screen-reader instructions before
one, without a second renderer or a second input subscription. Scripted native
records test observed provenance only; they are not physical keyboard evidence.
A custom adapter whose outer lease fails on restore confirms the accepted
gesture survives cleanup reporting.

Gaps: all evidence is scripted or synthetic. No native keyboard/paste, real
terminal, real screen reader, human accessibility or real light/dark visual
check was performed, and no qualification is claimed. ASCII, `NO_COLOR` and
narrow geometry are checked in scripted output; unframed paste still cannot be
distinguished from typing. The public breaking cutover and human evidence gates
remain later tickets.
