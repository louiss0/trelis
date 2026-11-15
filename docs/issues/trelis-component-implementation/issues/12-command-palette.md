# 12: Deliver CommandPalette

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a public searchable CommandPalette that returns an explicitly accepted command identity without executing it. It shares SearchSelect's default matching and query/result focus while making availability, no-match and dismissal clear.

**Blocked by:**
- [11: Deliver SearchSelect](11-search-select.md)

**Status:** resolved

- [x] Default substring matching and original order are preserved; optional fuzzy ranking is explicit, deterministic and described.
- [x] Navigation, query editing and preview never execute commands or other application effects.
- [x] Explicit result acceptance returns stable command identity; unavailable/disabled commands remain discoverable and cannot be accepted.
- [x] Raw unmatched query text cannot be submitted or executed as a command.
- [x] Public tests prove application-owned execution remains outside the component and no accepted result is fabricated during no-match/error states.
