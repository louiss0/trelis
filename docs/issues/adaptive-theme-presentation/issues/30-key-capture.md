# 30 Migrate key capture prompts

Status: ready-for-agent

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

- [ ] Test real Keypress and KeyChordInput components in rich, linear and screen-reader modes, preserving key/chord values, modifiers and existing capture semantics.
- [ ] Display capture, validation and result states intelligibly with textual labels and independent indicators, including Unicode, ASCII, `NO_COLOR` and narrow layouts.
- [ ] Show mandatory compact primary-action/help hints at rich bottom and after normal linear content; put essential screen-reader instructions before each prompt, even when instructions are hidden.
- [ ] Provide and identify a component-safe help route that never steals a gesture intended for capture or reinterprets captured keys as help/cancel; test detailed help and preservation of in-progress capture state.
- [ ] Independently test literal and special keys, chords, control sequences, escape/cancel behavior, paste handling where applicable, validation retries and cleanup without weakening capture safety.
- [ ] Route capture and any delegates through theme-owned interaction, colors and input ownership, without a competing reader or a second external prompt; preserve availability checks.
- [ ] Verify accepted, invalid/retry, cancelled, interrupted, unavailable and `InputEnded` outcomes, plus sequential reuse from configured initial state and concurrent prompt rejection.
- [ ] Record automated tests and commands/results, and identify missing native-terminal and human screen-reader checks rather than claiming qualification.
