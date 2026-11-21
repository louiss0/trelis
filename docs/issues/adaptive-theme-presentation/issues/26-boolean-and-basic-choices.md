# 26 Migrate boolean and basic choice prompts

Status: claimed

**Blocked by:** [09](09-state-and-compact-help.md)

**What to build:** Migrate Confirm, Checkbox, Toggle, Select, Radio and MultiSelect using the internal theme/session and shared state/help seams, without prematurely publishing the prototype or breaking existing calls. The [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md) govern behavior.

## Proposed examples — NOT IMPLEMENTED

```dart
final confirmation = RailTheme().confirm('Continue?');
final answer = await confirmation.prompt();
```

```dart
final choices = RailTheme().multiSelect('Features', options); // List<Choice<T>>
final first = await choices.prompt();
final again = await choices.prompt(); // Configured initial selection, not first.
```

## Acceptance criteria

- [ ] Cover each named component with real component tests in rich, normal linear and screen-reader presentation; preserve boolean, choice and result types and selection semantics.
- [ ] Test focus, selected/checked, unchecked and default as independent states, including all five theme-wide single-selection styles; default does not imply selection. Verify ASCII pairs and meaningful `NO_COLOR` output.
- [ ] Keep locked `[L]` and unavailable `[!]` choices focusable but not selectable or acceptable, with readable reasons in rich and linear output; preserve validation and navigation safety.
- [ ] Always show compact primary-action/help guidance despite hidden instructions, at rich bottom or after normal linear content; put screen-reader essential guidance before the prompt. Detailed help preserves selection, focus and any draft/caret.
- [ ] Route components and internal delegates through theme-owned session, interaction and colors; never treat a delegate as a second external prompt or add invocation-level I/O.
- [ ] Test acceptance, validation failure/retry, cancel, interrupt, unavailable and `InputEnded`, and sequential reuse from configured initial values; reject concurrent prompt invocations.
- [ ] Verify narrow layouts, Unicode and ASCII, no-color rendering and control behavior independently for each affected family, including safe help and any editable or pasted input.
- [ ] Record automated regression commands/results and any missing human screen-reader or native visual evidence; scripted tests alone do not qualify accessibility.
