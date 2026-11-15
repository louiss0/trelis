# 08: Deliver Confirm, Checkbox, and Toggle

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver three public boolean component presentations with draft-only changes and explicit submission. Confirm defaults visibly to No unless configured otherwise; Checkbox and Toggle default to false/off unless configured otherwise. Rich and linear interactions return the same boolean answer without applying application side effects.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Confirm's rich Yes/No shortcuts change only the draft and Enter submits; linear documented answer lines provide equivalent acceptance.
- [x] A configured Confirm default is visible; absent an override the default is No, and EOF never accepts it.
- [x] Checkbox and Toggle expose checked/unchecked or on/off state in text, toggle rich drafts with Space and submit explicitly.
- [x] Linear boolean entry offers equivalent explicit choices and accepts a completed empty line as the displayed default where specified.
- [x] No component executes consequences or exits the application; cancellation/interruption never becomes a boolean answer.
