# 05: Deliver Multiline

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver rich and linear multiline editing without requiring modified Enter. Rich Enter inserts a newline and visible actions finish the value. Linear interaction accumulates, reviews and corrects logical lines with explicit commands. Results preserve intentional blank/final blank lines with documented LF normalization.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Rich Enter inserts a newline, Tab reaches visible actions including Finish, and literal tabs remain enterable through an explicit action or paste.
- [x] Linear /list, /edit, /insert, /remove and /done provide review, correction, insertion, confirmed deletion and explicit submission.
- [x] Existing-line editing uses a genuinely editable initial value; blank lines and intentional final blank lines survive.
- [x] Pasted CRLF and CR normalize explicitly to LF, other text remains preserved, and pasted newlines never replay commands.
- [x] Invalid final input, cancellation and EOF preserve the shared outcome/draft guarantees and never implicitly finish content.
