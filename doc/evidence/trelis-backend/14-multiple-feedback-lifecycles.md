# Ticket 14 — multiple feedback lifecycle evidence

**Status:** pass for the scripted public shared-session seam.

## Source and environment

- **Implementation revision:** `bbccf1046ec27a62a47c6bb650872f8f9d452695`
- **Branch:** `ticket/backend-14-feedback-lifecycles`
- **Environment:** Windows (`windows_x64`), Dart SDK 3.13.2 stable
- **Output/input:** synthetic `StringBuffer` output and scripted stream input
- **Profiles:** declared 40×8 ASCII, monochrome rich profile and explicit linear mode

## Public scenarios

`test/terminal_session_feedback_test.dart` exercises one explicit
`TerminalSession` with actual `Spinner`, `Progress`, and `MultiSpinner`
instances while an actual `TextInput.prompt(session:)` is editing. In both
rich and linear modes it verifies the accepted draft (`demo`) and logical
caret (4), observed status/outcome output, and MultiSpinner's ordered
all-task summary. The rich scenario further confirms that reaching a progress
total does not create `completed`, disposal does not manufacture an outcome,
and updates after a completed MultiSpinner task or after session-scope
retirement cannot revive output.

`test/feedback_test.dart` supplies an application-controlled `FeedbackClock`
to actual Progress and MultiSpinner instances. Advancing that clock delivers
only the pending coalesced update, demonstrating that cadence is independent
of rendering and does not require wall-clock sleeps.

## Executed verification

| Command | Result |
| --- | --- |
| `dart test test/feedback_test.dart test/multi_spinner_test.dart test/terminal_session_feedback_test.dart --reporter expanded` | Passed: 25 tests |
| `git diff --check` | Passed: no whitespace errors |

## Limitations

The evidence is deterministic scripted public behavior only. It does not
exercise native PTYs, real terminal repaint/caret observation, resize or
short-height composition, session-modal help, shared-writer failure handling,
or Linux/macOS CI. Those remain for their dedicated tickets and the final
backend evidence gate.
