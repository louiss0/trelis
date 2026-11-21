# 31 Migrate feedback components

Status: resolved

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

- [x] Exercise all four real feedback components in rich and linear output, including screen-reader presentation; preserve feedback values and distinguish running, progress, success, warning and failure states as applicable.
- [x] Use textual status labels and symbols rather than color alone; test Unicode, ASCII, `NO_COLOR`, reduced output capabilities and narrow screens. Do not add artificial help to noninteractive feedback; show guidance only for an actual user action.
- [x] When feedback coexists with an interactive prompt, preserve that prompt's mandatory compact help at rich bottom or after normal linear content and its essential screen-reader instructions before the prompt, even with hidden instructions; preserve draft, focus and caret through help and updates.
- [x] Use common asynchronous theme initialization for feedback-first and prompt-first operations; resolve interaction and colors before output, respect configuration conflicts and unavailable rich mode, and do not publish a failed resolution.
- [x] Verify one active prompt with multiple coordinated feedback jobs, internal delegation, modal help, resize and short screens; ending the prompt must not stop live feedback. Stop, complete or fail feedback explicitly and retire timers/producers and regions.
- [x] Verify successful completion, failure, cancellation where supported, writer/restoration errors and cleanup without losing a primary outcome; the last active component releases resources automatically, and a later start safely reacquires them.
- [x] Test sequential reuse of feedback where supported, caller-owned streams, callback failure and start racing cleanup; retain existing safety and avoid competing input readers or invocation-level I/O.
- [x] Add automated component and lifecycle regressions, record commands/results and missing real-terminal or human screen-reader evidence; scripted tests do not establish accessibility qualification.

## Comments

Added an internal, non-exported `lib/src/theme_feedback_tracer.dart` seam that
creates the four real feedback components inside one `ThemeSession` period.
`feedback.dart` now accepts a renderer only through themed internal
constructors, so direct construction and all existing `present`/`start`
parameter lists remain buildable until ticket 32. Theme-owned lines use the
merged `renderStatus` vocabulary: Unicode `✓`/`!`/`×` or ASCII `+`/`!`/`x`
with text labels, text-only labels in screen-reader presentation, and no
help route. Running, progress, recalculation and each explicit outcome keep
distinct labels and values. Structural framing, resolved component colours,
`NO_COLOR`, glyph capability and fixed-width wrapping come from the owned
period; `ThemeSessionHandle.componentColors` now hosts the layering helper
shared with the text-input tracer.

Validation on this branch:

- `dart test test/theme_feedback_components_test.dart -r compact` — 22 passed.
- `dart test test/feedback_test.dart test/multi_spinner_test.dart test/theme_session_coordinated_feedback_test.dart test/terminal_session_feedback_test.dart test/theme_state_help_tracer_test.dart test/theme_text_input_tracer_test.dart -r compact` — 67 passed.
- `dart test -r compact` — 5025 passed.
- `dart format --output=none --set-exit-if-changed .` — 255 files, 0 changed.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker.

Decisions: feedback components remain caller-owned value objects; only their
formatting path is selected by the theme, and live participants still finish
through `ThemeSession.startFeedback`, so timers, regions and leases retire in
one place. The tracer returns an explicit control whose `finish` records a
completed, failed, cancelled, interrupted or skipped outcome and whose `stop`
records no invented outcome. Prompt compact help, hidden-instruction behavior,
screen-reader essential text and modal help remain provided by the existing
prompt/session seams; the new tests assert they survive coordinated feedback.
Owner-level start-racing-cleanup and internal-delegation regressions live in
`test/theme_session_cleanup_test.dart` and were rerun in the full suite rather
than duplicated here.

Gaps: all evidence is scripted or synthetic. No native Windows/macOS console,
real screen reader, real light/dark terminal, human accessibility, live
resize observation, or component-level delayed-cleanup race was collected.
The public cutover, native detection and human evidence gates remain separate
tickets; this does not claim accessibility qualification.
