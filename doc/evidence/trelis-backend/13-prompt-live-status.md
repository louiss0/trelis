# Ticket 13 — prompt with live status evidence

**Status:** pass for the scripted public rich-session seam.

## Public scenario

`test/terminal_session_feedback_test.dart` opens an explicit `TerminalSession` using a synthetic rich profile, starts an actual `Spinner`, presents actual informational `Text`, and then runs `TextInput.prompt(session:)`. While the editor is awaiting input, the spinner updates and completes. The test verifies the ordered status/text output and the public `TextInputTranscript` current view (`demo`, caret 4), demonstrating that status writes cause a repaint from the logical editor state rather than consuming input or reconstructing the draft.

The session owns the selected output while the callback runs. Attached feedback inherits its profile/mode and routes through its typed, generation-checked feedback registration; terminal sessions on the same output fail rather than becoming an implicit shared screen. Attached `Text` and feedback reject competing output/terminal/presentation configuration. Explicit feedback completion retires only its presentation region and does not manufacture an application outcome on disposal.

## Executed verification

Windows, Dart SDK selected by the repository, scripted streams and recording `StringBuffer` output:

| Command | Result |
| --- | --- |
| `dart test test/terminal_session_feedback_test.dart test/terminal_session_test.dart test/feedback_test.dart --reporter expanded` | 20 tests passed |
| `dart analyze` | `No issues found!` |

## Limitations

This is scripted public behavior, not native PTY, visible terminal, resize-at-short-height, alternate-screen help, or Linux/macOS CI evidence. The live writer clears and repaints the active rich editor; it does not claim a general-purpose terminal widget/layout framework or qualification of physical terminal rendering. Those broader B-RESIZE/B-MODAL/B-PLATFORM/B-GUI requirements remain for their dedicated tickets and final gate.

## Final-review revalidation

The final backend review found that the standalone feedback claim token was a
no-op, so a session could take a screen that unowned standalone feedback was
already writing into. The claim is now reference-counted on the selected sink
(`5f5e4bb`) with public tests in `test/terminal_session_feedback_test.dart`;
independent standalone feedback on one sink and the session-first rejection
remain unchanged. See [final-review-fixes.md](final-review-fixes.md).
