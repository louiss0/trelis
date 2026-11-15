# 26: Deliver DurationInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver explicit elapsed or calendar-relative duration entry using human unit tokens. Elapsed values have fixed exact-microsecond meaning; calendar-relative values remain unapplied periods with retained components rather than an invented date/zone or fixed-second total.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] The application selects elapsed or calendar-relative mode before entry; unit tokens cannot trigger implicit mode switching or reinterpretation of a draft.
- [x] Case-sensitive w, d, h, m, s, ms and us, plus y and mo in calendar mode, use ASCII amounts/dot fractions with no grouping or locale guessing.
- [x] Nonnegative is the default, zero follows configured minimum, signed mode uses one global sign, and duplicate units/mixed component signs are rejected with drafts retained.
- [x] Elapsed day/week are fixed 24-hour/seven-day units; all accepted values/fractions convert exactly to integer microseconds or fail without truncation/overflow.
- [x] Calendar y/mo/w/d components remain whole and sub-day components retain elapsed meaning; no built-in calendar application, endpoint, arithmetic order or DST policy is invented.
