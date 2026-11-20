# 07 Coordinate live feedback with prompts

Status: claimed

**Blocked by:** [06](06-automatic-cleanup.md)

**What to build:** Route one-shot and live feedback through the theme owner while allowing one prompt alongside live feedback. Feedback retains appropriate `present` and `start` operations; initialize asynchronously before first output when needed. A prompt ending must not stop independent feedback; the final participant triggers automatic cleanup. Maintain existing public calls until cutover. See the [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final progress = theme.spinner('Working');
await progress.start();
final answer = await theme.textInput('Name').prompt();
progress.finish(FeedbackOutcome.completed); // Last active component releases resources.
```

## Acceptance criteria
- [ ] Test feedback-first and prompt-first, multiple coordinated feedback instances, and stop/complete/failure while the prompt remains active or has ended; callback and detection are shared once per active period.
- [ ] Using an injected asynchronous detection result, prevent output before initialization finishes or safely falls back; unavailable rich mode produces a clear feedback error and no output. Native background query routing is implemented and tested separately in ticket 33.
- [ ] Verify producers/timers are cancelled as well as screen regions retired on stop and failure; cover failed writer, modal help, resize, short screens and restoration failures without losing primary errors.
- [ ] Demonstrate later work reacquires after cleanup, without closing caller streams; record scripted test commands and limitations of native evidence.
