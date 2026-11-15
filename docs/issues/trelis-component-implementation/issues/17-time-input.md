# 17: Deliver TimeInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver time-of-day-only entry with explicit precision and format. Users can enter or edit labeled hour/minute/optional-second segments, including explicit 12-hour period when configured, without the component inferring date, timezone or a UTC instant.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Default format is 24-hour HH:mm; optional seconds and 12-hour input are explicit with prominently advertised required period.
- [x] Tab traverses labeled segments/actions; Up/Down adjusts locally and stops at segment boundaries without carry or wrap.
- [x] Direct formatted entry is available in both modes and incomplete/invalid text remains correctable.
- [x] 24:00, invalid minutes/seconds and missing periods are not silently normalized into another value.
- [x] Accepted outcomes preserve only the declared time-of-day meaning, never midnight/date/zone assumptions.
