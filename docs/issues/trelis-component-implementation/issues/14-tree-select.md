# 14: Deliver TreeSelect

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a public TreeSelect that returns one explicitly selectable node while allowing independent branch traversal and expansion. Rich and linear interactions expose hierarchy/path, expanded state, selection eligibility and unavailable reasons without implicit descendant selection.

**Blocked by:**
- [09: Deliver Select and Radio](09-select-radio.md)

**Status:** resolved

- [x] Leaf-only selection is the default; selectable branches require explicit configuration and never imply selecting descendants.
- [x] Rich Up/Down traverses visible rows, Right expands/enters children, Left collapses/goes to parent, and Enter submits only a selectable enabled node.
- [x] Linear /open, /up and /choose provide separate explicit branch navigation and node acceptance with full path context.
- [x] Focused/expandable/selectable/unavailable states are distinguishable without color or indentation alone.
- [x] Root, empty, lazy/error and removed-node cases never invent descendants or silently substitute another answer.
