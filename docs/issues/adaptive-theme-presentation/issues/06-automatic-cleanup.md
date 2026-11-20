# 06 Automatically clean up active work

Status: resolved

**Blocked by:** [05](05-theme-owned-session.md)

**What to build:** Manage lazy resource participation and automatically await restoration after the last active component ends, including feedback that is stopped, completed or fails. Later work starts a new active period and re-detects; do not add public theme close. Preserve public compatibility until cutover. See the [design](../../../adaptive-theme-accessibility-design.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final prompt = theme.textInput('Name');
final first = await prompt.prompt(); // Last work ends; cleanup is awaited.
final second = await prompt.prompt(); // Fresh period and initial value.
```

## Acceptance criteria
- [x] Test prompt completion while feedback remains active, all feedback terminal paths, cleanup only after the final participant and sequential prompt reuse resetting its initial value.
- [x] Reject a second concurrent external prompt and overlapping identifiable owners across themes; allow internal composite delegation and sequential use by different themes. Document unidentifiable-wrapper limitations.
- [x] Race a new start against delayed cleanup and assert it waits for release, reacquires and re-detects; callback runs once per successful period, not once per component.
- [x] Inject primary and cleanup failures together: preserve answer, EOF or primary failure and make cleanup failure observable; test caller-owned streams remain open and `InputEnded` for exhausted scripted input. Record test commands and results.

## Comments

Extended the internal `ThemeSession` owner in `lib/src/theme_session.dart`: a period stops accepting work as soon as its last participant releases, starts are serialized behind cleanup, identifiable environments are registered across themes, a second external prompt is rejected while internal delegation still joins one period, and cleanup failures are retained through `cleanupFailures`/`onCleanupError` or aggregated with a primary failure as `TerminalSessionCleanupException`. No public barrel symbol, prompt signature or theme close method was added.

Validation on this branch after merging `integration/adaptive-theme-presentation` (already up to date):

- `dart test test/theme_session_test.dart test/theme_session_cleanup_test.dart test/theme_session_feedback_lifecycle_test.dart test/theme_session_reuse_test.dart test/terminal_session_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_session_feedback_test.dart test/terminal_environment_test.dart -r compact` — 63 passed.
- `dart test -r compact` — 4902 passed.
- `dart format --output=none --set-exit-if-changed .` — 234 files, 0 changed, exit 0.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.

Decisions: cleanup is awaited as part of the last operation, but a successful answer is returned even when cleanup fails; the failure stays observable through the owner's diagnostics. A primary failure plus cleanup failure keeps both causes without stringifying either. Overlap rejection uses the environment's supplied identity; distinct unidentifiable wrappers cannot be proven to share a terminal and are not rejected by that seam, while the selected output's screen claim still guards the same sink.

Gaps: all evidence is synthetic or scripted. No native Windows/macOS console, reader, real light/dark terminal, human screen-reader, background-query or ownership-identity probe evidence was collected here. Full feedback component migration, coordinated rendering and platform detection remain later tickets; scripted `InputEnded` and caller-stream tests do not establish native behavior.
