# 27: Deliver DateInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver slash-based DateInput following qualified effective system conventions and the locale's actual calendar, including genuine supported non-Gregorian calendars. Users can understand/edit locale-ordered fields, explicit era/leap-month context and disclosed short-year meaning, review the interpreted civil date, and receive a date-only result with canonical civil identity and preserved calendar meaning.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] A qualified source/provider resolves effective user/process date preferences with a stable per-prompt snapshot, visible field/order/calendar/digit/window instructions, and explicit supported override rather than Gregorian/order fallback.
- [x] Slash fields and context choices retain required era, year-of-era, leap/intercalary month identity and valid provider/range semantics without three-number or current-era assumptions.
- [x] ASCII plus resolved native decimal digits are accepted consistently within each numeric field; short years use only an exact disclosed frozen system century window.
- [x] Rich slash/Tab navigation and local bounded adjustment never submit/carry; dependent invalid fields remain preserved rather than clamped, and linear mode supplies equivalent context/review/edit actions.
- [x] Strict complete validation and field/month-identity round-trip precede explicit review; accepted results retain canonical civil-date identity plus calendar/variant/fields/provenance without midnight, timezone or public timestamp invention.
