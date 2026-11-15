# 02: Prove editable defaults and shared Windows + NVDA interaction

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver and evaluate a small real terminal interaction probe before bulk component work. In both plain-rich and linear presentation, a person can discover and correct an actual editable initial value, understand labels/current state, recover from invalid input, use secret-safe editing and meaningful bounded status, and cancel or interrupt without losing terminal usability. The human's manual scope is Windows Terminal + NVDA only.

**Blocked by:**
- [01: Prove the terminal backend and restoration lifecycle](01-terminal-backend-lifecycle-probe.md)

**Status:** resolved

- [x] Both presentations provide genuinely editable initial values, including erasure and command/backslash collisions, rather than a pending-default substitute.
- [x] Actual Windows Terminal + NVDA tasks cover instruction discovery, correction, hidden secrets, meaningful status, layered Escape, Ctrl+C and restoration.
- [x] Identified paste remains literal and its provenance survives editing; unframed-paste limitations are documented rather than hidden.
- [x] The probe records exact OS/terminal/shell/NVDA/backend versions and settings, with sanitized observed evidence and no real secrets.
- [x] A failed required task blocks bulk implementation and reopens the relevant decision; a pass is recorded before ticket completion.
