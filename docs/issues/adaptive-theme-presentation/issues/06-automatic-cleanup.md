# 06 Automatically clean up active work

Status: claimed

**Blocked by:** [05](05-theme-owned-session.md)

**What to build:** Manage lazy resource participation and automatically await restoration after the last active component ends, including feedback that is stopped, completed or fails. Later work starts a new active period and re-detects; do not add public theme close. Preserve public compatibility until cutover. See the [design](../../../adaptive-theme-accessibility-design.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final prompt = theme.textInput('Name');
final first = await prompt.prompt(); // Last work ends; cleanup is awaited.
final second = await prompt.prompt(); // Fresh period and initial value.
```

## Acceptance criteria
- [ ] Test prompt completion while feedback remains active, all feedback terminal paths, cleanup only after the final participant and sequential prompt reuse resetting its initial value.
- [ ] Reject a second concurrent external prompt and overlapping identifiable owners across themes; allow internal composite delegation and sequential use by different themes. Document unidentifiable-wrapper limitations.
- [ ] Race a new start against delayed cleanup and assert it waits for release, reacquires and re-detects; callback runs once per successful period, not once per component.
- [ ] Inject primary and cleanup failures together: preserve answer, EOF or primary failure and make cleanup failure observable; test caller-owned streams remain open and `InputEnded` for exhausted scripted input. Record test commands and results.
