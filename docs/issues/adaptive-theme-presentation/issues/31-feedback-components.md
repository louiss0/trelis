# 31 Migrate feedback components

Status: claimed

**Blocked by:** [07](07-coordinated-feedback.md), [09](09-state-and-compact-help.md)

**What to build:** Migrate Text, Progress, Spinner and MultiSpinner through the theme-owned feedback and presentation seams, retaining `.present()` and `.start()` rather than forcing feedback into `.prompt()`. Keep existing public calls buildable until coordinated cutover. Follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Proposed examples — NOT IMPLEMENTED

```dart
final message = RailTheme().text('Ready');
await message.present();
```

```dart
final spinner = RailTheme().spinner('Working');
await spinner.start();
spinner.finish(FeedbackOutcome.completed); // Live feedback ends explicitly.
```

## Acceptance criteria

- [ ] Exercise all four real feedback components in rich and linear output, including screen-reader presentation; preserve feedback values and distinguish running, progress, success, warning and failure states as applicable.
- [ ] Use textual status labels and symbols rather than color alone; test Unicode, ASCII, `NO_COLOR`, reduced output capabilities and narrow screens. Do not add artificial help to noninteractive feedback; show guidance only for an actual user action.
- [ ] When feedback coexists with an interactive prompt, preserve that prompt's mandatory compact help at rich bottom or after normal linear content and its essential screen-reader instructions before the prompt, even with hidden instructions; preserve draft, focus and caret through help and updates.
- [ ] Use common asynchronous theme initialization for feedback-first and prompt-first operations; resolve interaction and colors before output, respect configuration conflicts and unavailable rich mode, and do not publish a failed resolution.
- [ ] Verify one active prompt with multiple coordinated feedback jobs, internal delegation, modal help, resize and short screens; ending the prompt must not stop live feedback. Stop, complete or fail feedback explicitly and retire timers/producers and regions.
- [ ] Verify successful completion, failure, cancellation where supported, writer/restoration errors and cleanup without losing a primary outcome; the last active component releases resources automatically, and a later start safely reacquires them.
- [ ] Test sequential reuse of feedback where supported, caller-owned streams, callback failure and start racing cleanup; retain existing safety and avoid competing input readers or invocation-level I/O.
- [ ] Add automated component and lifecycle regressions, record commands/results and missing real-terminal or human screen-reader evidence; scripted tests do not establish accessibility qualification.
