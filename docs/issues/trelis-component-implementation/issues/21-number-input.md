# 21: Deliver NumberInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver finite base-10 numeric entry with integer default and explicit decimal mode. Effective system noncurrency conventions govern supported separators, grouping, signs and native digits, while exact decimal interpretation prevents silent precision loss. Unresolved conventions require explicit supported override and never silently change an active draft.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Integer and decimal modes exclude hex, exponent, NaN, infinity, currency and percent forms; integer mode rejects decimal notation.
- [x] Effective system user/category preferences, not just locale name, drive visible numeric conventions; actual sources and limitations are pinned and disclosed.
- [x] Ungrouped and exactly correctly grouped input are accepted; malformed/mixed separators, unsupported digit systems and mixed-script numbers are rejected.
- [x] ASCII plus the resolved native decimal repertoire are accepted consistently per number, and supported sign/negative patterns are strictly advertised.
- [x] Bounds, precision and optional adjustment use exact decimal meaning without silent rounding/overflow; a coherent convention snapshot and explicit override handle unsupported/changed preferences.
