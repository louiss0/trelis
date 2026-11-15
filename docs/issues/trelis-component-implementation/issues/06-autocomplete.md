# 06: Deliver Autocomplete

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a public Autocomplete component where suggestions assist independently valid text entry rather than impose an allowed-value list. Suggestion activation, acceptance into editable text and final submission remain distinct in rich and linear interaction.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Merely displaying suggestions does not activate a candidate or intercept Enter; valid unmatched text can submit.
- [x] Rich navigation activates candidates, Tab accepts active/first offered suggestions, Enter accepts an active unaccepted candidate without submitting, and Escape dismisses suggestions first.
- [x] Linear query entry, numbered suggestions and explicit /submit, /edit, /help and /cancel actions support the same task outcomes.
- [x] No-match still permits valid free text, and accepted-versus-unaccepted candidate state is explicit.
- [x] Stale asynchronous suggestions cannot replace newer results or silently commit a candidate; query editing remains ordinary text input.
