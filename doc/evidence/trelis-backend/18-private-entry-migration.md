# Ticket 18: private-entry migration evidence

Source branch: `ticket/backend-18-private-entry`

Environment: Windows, repository Dart SDK.

## Public behavior exercised

- `Password.prompt` and `URLInput.prompt` run through an explicit `TerminalSession`, inherited output profile, shared writer and feedback repaint path.
- Password drafts, caret position, paste provenance and validation canaries remain absent from output and `TextInputTranscript`; masking and prefill disclosures remain explicit.
- Password stage actions and help remain separate from literal secret entry, and validation failures return the generic public result.
- URL drafts remain hidden while the component-approved accepted host interpretation is retained; tests make no claim that arbitrary path/query text can be safely echoed.
- Rich and linear behavior is covered through public component calls, including background feedback updates.

## Verification

- `dart analyze`: no issues.
- `dart test test/password_test.dart test/url_input_test.dart test/terminal_session_feedback_test.dart --reporter expanded`: 24 tests passed.
- Full-suite verification is recorded in the implementing commit/merge report.

## Limitations

This is deterministic scripted public-behavior evidence. Native PTY, visible terminal, GUI/NVDA, Linux/macOS CI, modal composition and final backend-gate evidence remain assigned to their dedicated tickets.
