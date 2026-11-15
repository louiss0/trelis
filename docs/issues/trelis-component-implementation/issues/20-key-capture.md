# 20: Deliver Keypress and KeyChordInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver logical key-gesture capture and ordered key-sequence entry with explicit capture/review/submission. Components describe only observable keys/modifiers, support clearly distinguished textual declaration, preserve per-gesture provenance, and retain safe cancellation/interruption.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Explicit Capture next gesture arms one capture and returns to review/actions; no immediate acceptance or timing-based sequence completion occurs.
- [x] Keypress returns one gesture; KeyChordInput builds one-or-more ordered gestures with explicit add, remove-last, clear and submit actions.
- [x] Logical key/modifier and observed/declared provenance are retained per gesture; repeat events do not add extra gestures from one arming.
- [x] A documented declaration path supports unavailable capture, never claims observed delivery, and can be rejected when the caller requires observation.
- [x] Ctrl+C always interrupts and Escape exits armed capture before root cancellation; neither is observed as a live binding, and declarations carry reserved/unverified warnings.
