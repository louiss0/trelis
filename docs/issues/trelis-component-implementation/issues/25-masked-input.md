# 25: Deliver MaskedInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver format-constrained fixed and adaptive masked entry as a public component, distinct from secrets. Users can edit stable slots, inspect raw/formatted/template meanings, explicitly resolve adaptive ambiguity, and paste raw/formatted data only when interpretation is unambiguous.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Declared fixed or finite named adaptive templates define editable grapheme slots and literal separators; literals are presentation rather than editable data.
- [x] Adaptive activation is automatic only for a unique fitting candidate; multiple valid interpretations require explicit choice, never hidden configuration-order selection.
- [x] Rich typing overwrites the focused slot, Backspace/Delete clear adjacent slots without shifting later data, and linear review/slot correction/template selection provide equivalent tasks.
- [x] Raw slot data, formatted value and selected template identity remain distinct for acceptance/re-editing; incomplete required slots block submission with retained drafts.
- [x] Raw/formatted paste is accepted automatically only when unambiguous; differing interpretations preserve the paste and request explicit resolution without punctuation stripping or command replay.
