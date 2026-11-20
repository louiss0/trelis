# 29 Migrate filesystem and network prompts

Status: ready-for-agent

**Blocked by:** [25](25-text-secret-multiline.md)

**What to build:** Migrate PathInput, FilePicker, DirectoryPicker, IpAddressInput, UrlInput and EmailInput using theme-owned internal session and presentation seams. Preserve public calls until the coordinated cutover; follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Proposed examples — NOT IMPLEMENTED

```dart
final path = RailTheme().pathInput('Destination');
final result = await path.prompt();
```

```dart
final email = RailTheme().emailInput('Contact');
final first = await email.prompt();
final again = await email.prompt(); // Restarts from configured initial value.
```

## Acceptance criteria

- [ ] Exercise every named real component in rich, linear and screen-reader modes, preserving filesystem navigation, filters, validation, typed values and existing outcomes.
- [ ] Present focus, selected path, validation and unavailable states with readable text and non-color indicators; cover Unicode, ASCII, `NO_COLOR`, narrow layouts and screen-reader textual descriptions.
- [ ] Always show compact primary-action/help hints at rich bottom or after normal linear content, and essential screen-reader instructions before the prompt, even when instructions are hidden. Help preserves path/query draft, focus and caret.
- [ ] Independently verify safe editing: escaped or identified pasted command-shaped values survive invalid retries, help/cancel work even with short value limits, and recognized multiline paste into single-line fields is rejected while preserving the draft; capability-check and clean up paste reporting.
- [ ] Test representative filesystem paths, file/directory filtering and inaccessible entries, IP address, URL and email validation and retries without weakening existing safety or changing domain semantics.
- [ ] Delegate internally via the theme owner and resolved interaction/colors without starting a second external prompt or competing input reader; do not add per-invocation I/O configuration.
- [ ] Test success, invalid retry, cancellation, interruption, unavailable and `InputEnded`, sequential reuse from configured initial values, and concurrent prompt rejection.
- [ ] Add automated family/session tests and record commands/results and missing native-terminal or human screen-reader evidence; scripted coverage is not accessibility qualification.
