# 01 Input-event-local CRLF decoding and Multiline finish

Status: ready-for-agent

**Blocked by:** none

**What to build:** Repair the shared terminal reader and Multiline behavior so CR inserts newline/activates the focused action while separately delivered LF/Ctrl+J finishes. Implement input-event-local CRLF normalization only when CR and LF arrive together in one decoded input event; never persist CR state across events, reads, or time. Preserve framed paste atomically as draft data after CRLF/CR normalization. Add public theme-instance regression coverage for Enter followed by separately delivered Ctrl+J, trailing blank-line preservation, validation failure, same-event CRLF, separate CR then LF, and framed CRLF paste. Document the unframed-paste ambiguity without weakening the key contract. See the [spec](../spec.md), especially “Key gestures and CRLF decoding”.

## Acceptance criteria

- [ ] Ctrl+J reliably finishes after Enter has inserted a trailing newline in rich Multiline interaction through the public theme-instance seam.
- [ ] Same-event CRLF normalizes to CR/newline behavior, while separately delivered CR then LF reaches the component as newline then finish.
- [ ] Framed paste containing CRLF remains draft data and cannot trigger finish; unframed ambiguity is honestly documented.
- [ ] No second decoder or component-specific parallel reader is introduced; regression coverage observes emitted gestures/outcomes rather than private state.
- [ ] Relevant shared-reader, Multiline, public theme-instance, formatter, analyzer, and focused tests pass.

## Comments
