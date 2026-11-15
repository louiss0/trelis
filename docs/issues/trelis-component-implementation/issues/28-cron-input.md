# 28: Deliver CronInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver explicitly selected Cronie-style five-field and Quartz cron expression entry with strict dialect semantics and no command execution or job registration. An expression can be accepted without preview. Optional previews require complete finite context and honestly describe bounded civil-time matching rather than scheduler emulation.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Unix and Quartz profiles are explicitly selected, never field-count guessed, with advertised field ranges, day-combination rules, weekday numbering, special tokens and qualified supported ranges.
- [x] Unix excludes commands, directives, random extensions and macros; Quartz validates its seconds/six-field/optional-year and special-token grammar without importing Unix day rules.
- [x] Accepted results preserve expression and profile meaning; no schedule registration, job execution, daemon configuration or expression extraction from command lines occurs.
- [x] Optional preview requires declared provider/IANA zone/data version/reference instant/result count/start-end/work budget, with next strictly after the reference and no hidden horizon.
- [x] Matching preview skips nonexistent local times, includes both repeated-time instants, bounds work responsively, and distinguishes no-match-in-horizon, budget exhaustion, unsupported range and provider error without claiming scheduler emulation.
