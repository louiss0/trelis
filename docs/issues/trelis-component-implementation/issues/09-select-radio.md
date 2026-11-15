# 09: Deliver Select and Radio

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver two single-choice public components with shared answer semantics and their distinct presentations. Users can review available and unavailable choices, navigate without submitting, and accept an enabled focused item explicitly. Stable identity and deterministic initial focus prevent accidental substitution.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Arrows navigate and Enter chooses/submits the focused enabled item; ordinary list navigation stops at boundaries by default.
- [x] Initial focus uses configured default, then first enabled available choice, then first available choice; unavailable focus warns and cannot submit.
- [x] Disabled choices remain focusable with reasons, while stale/removed references and invalid defaults never silently choose another item.
- [x] Linear selection uses stable displayed item references with paging/review for long lists and no label-based ambiguity.
- [x] Focus/default/selection states remain distinct in text and cancellation produces no accepted choice.
