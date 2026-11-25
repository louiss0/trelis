# 01 Input-event-local CRLF decoding and Multiline finish

Status: resolved

**Blocked by:** none

**What to build:** Repair the shared terminal reader and Multiline behavior so CR inserts newline/activates the focused action while separately delivered LF/Ctrl+J finishes. Implement input-event-local CRLF normalization only when CR and LF arrive together in one decoded input event; never persist CR state across events, reads, or time. Preserve framed paste atomically as draft data after CRLF/CR normalization. Add public theme-instance regression coverage for Enter followed by separately delivered Ctrl+J, trailing blank-line preservation, validation failure, same-event CRLF, separate CR then LF, and framed CRLF paste. Document the unframed-paste ambiguity without weakening the key contract. See the [spec](../spec.md), especially “Key gestures and CRLF decoding”.

## Acceptance criteria

- [x] Ctrl+J reliably finishes after Enter has inserted a trailing newline in rich Multiline interaction through the public theme-instance seam.
- [x] Same-event CRLF normalizes to CR/newline behavior, while separately delivered CR then LF reaches the component as newline then finish.
- [x] Framed paste containing CRLF remains draft data and cannot trigger finish; unframed ambiguity is honestly documented.
- [x] No second decoder or component-specific parallel reader is introduced; regression coverage observes emitted gestures/outcomes rather than private state.
- [x] Relevant shared-reader, Multiline, public theme-instance, formatter, analyzer, and focused tests pass.

## Comments

## Answer

Implemented input-event-local CRLF normalization in the existing `SharedTerminalReader` (`lib/src/shared_terminal.dart`): a CR immediately followed by LF in the same decoded input event emits one CR gesture, while no CR state is retained across events, reads or time. No second decoder or component-specific reader was added.

Regression evidence:

- `test/shared_terminal_reader_test.dart` covers emitted gestures for same-event CRLF, separately delivered CR then LF, and framed paste whose CRLF crosses input-event boundaries.
- `test/public_multiline_input_test.dart` uses only the public theme-instance seam in rich interaction and covers Enter observed as a trailing blank line followed by separately delivered Ctrl+J acceptance, validation failure preserving the draft for a later Ctrl+J, same-event CRLF as newline data, and framed CRLF paste remaining draft data until Ctrl+J.
- `README.md` documents that framed paste is the lossless multiline paste route and that unframed paste remains ambiguous: same-event CRLF is Enter's newline gesture while separately delivered LF is Ctrl+J finish.

Commands run on this branch:

- `dart test test/shared_terminal_reader_test.dart test/public_multiline_input_test.dart test/public_theme_instance_test.dart test/theme_text_components_test.dart test/multiline_test.dart` — all 77 tests passed.
- `dart analyze` — no issues found.
- `dart format --output=none --set-exit-if-changed lib/src/shared_terminal.dart test/shared_terminal_reader_test.dart test/public_multiline_input_test.dart` — passed with no changes needed after formatting.
- `dart run tool/check_issue_tracker.dart` and `dart run tool/check_doc_links.dart` — passed.
