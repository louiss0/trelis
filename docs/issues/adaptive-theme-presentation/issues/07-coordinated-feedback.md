# 07 Coordinate live feedback with prompts

Status: resolved

**Blocked by:** [06](06-automatic-cleanup.md)

**What to build:** Route one-shot and live feedback through the theme owner while allowing one prompt alongside live feedback. Feedback retains appropriate `present` and `start` operations; initialize asynchronously before first output when needed. A prompt ending must not stop independent feedback; the final participant triggers automatic cleanup. Maintain existing public calls until cutover. See the [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final progress = theme.spinner('Working');
await progress.start();
final answer = await theme.textInput('Name').prompt();
progress.finish(FeedbackOutcome.completed); // Last active component releases resources.
```

## Comments

Added an internal feedback seam in `lib/src/theme_session.dart`: one-shot
`Text` presentation and live feedback participants join the same asynchronous
first-operation path as prompts. A live participant stays independent of the
prompt; its `finish` runs the component's end and stop actions, cancels its
timer, retires the region and releases participation. The last participant
triggers cleanup. Conflicts, unavailable rich output and cancellation before
publication produce a clear feedback error with no output. No public barrel
symbol, feedback call signature or theme close method was added.

Validation on this branch:

- `dart test test/theme_session_coordinated_feedback_test.dart -r compact` — 18 passed.
- `dart test test/theme_session_coordinated_feedback_test.dart test/theme_session_test.dart test/theme_session_cleanup_test.dart test/theme_session_feedback_lifecycle_test.dart test/theme_session_reuse_test.dart test/theme_background_query_test.dart test/feedback_test.dart test/multi_spinner_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_environment_test.dart -r compact` — 118 passed.
- `dart test -r compact` — 4945 passed.
- `dart format --output=none --set-exit-if-changed .` — 241 files, 0 changed, exit 0.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker.

Decisions: the owner supplies the session and resolved period; components keep
their existing `present`/`start` calls until the public cutover. The live
participant's stop callback is explicit so timers and regions are retired even
when a component's own end action fails. Primary failures keep their identity
and are combined with restoration failures through the existing cleanup
exception. Resize behavior is exercised by the existing shared-terminal test
`test/terminal_session_short_screen_test.dart`; modal help and short screens
are also driven through the new owner seam. Background query routing remains
ticket 33's seam and was not duplicated.

Gaps: all evidence is synthetic or scripted. No native Windows/macOS console,
real screen-reader, real light/dark terminal, human accessibility, or live
resize observation was collected. The owner cannot yet prove that distinct
unidentifiable wrappers share one physical terminal; ticket 33's native query
evidence and the platform gates remain separate.

## Acceptance criteria
- [x] Test feedback-first and prompt-first, multiple coordinated feedback instances, and stop/complete/failure while the prompt remains active or has ended; callback and detection are shared once per active period.
- [x] Using an injected asynchronous detection result, prevent output before initialization finishes or safely falls back; unavailable rich mode produces a clear feedback error and no output. Native background query routing is implemented and tested separately in ticket 33.
- [x] Verify producers/timers are cancelled as well as screen regions retired on stop and failure; cover failed writer, modal help, resize, short screens and restoration failures without losing primary errors.
- [x] Demonstrate later work reacquires after cleanup, without closing caller streams; record scripted test commands and limitations of native evidence.
