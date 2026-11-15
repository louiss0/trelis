# 15: Deliver SortableSelect

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver full-list reordering as a public component whose answer is a permutation of supplied identities, never a membership change. Explicit move mode and linear move actions provide equivalent ordering without requiring modified arrows, and locked anchors remain fixed.

**Blocked by:**
- [09: Deliver Select and Radio](09-select-radio.md)

**Status:** resolved

- [x] Rich Space picks up/drops, arrows move draft order with position feedback, Enter while moving only drops, and Enter while idle submits.
- [x] Escape reverts the current in-progress move before root cancellation; completed draft moves remain until acceptance/cancellation.
- [x] Linear /move requests stable item reference and destination separately, reports resulting order, and /done submits the permutation.
- [x] Locked anchors remain reviewable with reasons and cannot move or be crossed; forbidden moves do not partially rearrange the list.
- [x] Stable identity is separate from position, and no Ctrl+arrow or other enhanced protocol shortcut is required.
