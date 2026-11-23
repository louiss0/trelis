# 01 Cron field-cell model and validation

Status: claimed

**Blocked by:** none

**What to build:** The internal foundation for field-cell entry, with no UI. Define the per-profile ordered field-cell schema (unix: minute 0-59, hour 0-23, day-of-month 1-31, month 1-12 JAN-DEC, day-of-week 0-7 SUN-SAT with 0 and 7 both Sunday; quartz: second, minute, hour, day-of-month with `?`/`L`/`LW`/`L-n`/`L-nW`/`nW`, month, day-of-week 1-7 with `?`/`L`/`dL`/`d#n`, optional year 1970-2199), per-cell draft validation that returns field-specific errors, the Quartz `?` day-exclusivity rule, verbatim expression assembly (single ASCII space joins; quartz cell 6 empty emits a clean 6-field expression; 4096 UTF-16 code-unit bound including separators), and constructor `initialValue` validation (`ArgumentError` on malformed/out-of-range/padded/wrong-count non-empty values; valid values split into initial cells; every `.prompt()` run resets to them). Empty `initialValue` leaves all cells empty — never silently coerced to `*` or `?`. Reuse the existing `_valid`/`_quartzField`/`_compileQuartzFields` grammar machinery in `lib/src/cron_input.dart` rather than duplicating it. See the [spec](../spec.md) Implementation Decisions: profile-determined field-cell schemas, initial cell state, expression assembly, validation timing.

Prefer placing new code in a new `part` file (e.g. `lib/src/cron_field_cells.dart` added to the `part` list in `lib/src/text_input.dart`) so parallel tickets editing `cron_input.dart` conflict less.

## Acceptance criteria

- [ ] Internal API exposes the ordered field-cell descriptors per `CronProfile` (name, position `i/N`, range cue, optional flag for quartz year) and per-cell validation producing field-specific error messages.
- [ ] Quartz `?` exclusivity is checked after per-field syntax: exactly one of day-of-month and day-of-week cells may be `?`; violations identify the day cells.
- [ ] Assembly joins cells with single ASCII spaces, preserves token spelling/case verbatim, emits 6 fields for quartz when year cell is empty, and enforces the 4096 UTF-16 code-unit limit including separators.
- [ ] Non-empty `initialValue` is validated at construction (`ArgumentError` on failure) and split into initial cells (quartz 6-field paste-style values leave year cell empty); reusable prompts reset cells per invocation.
- [ ] Tests cover unix/quartz schemas, per-field errors, `?` rule, verbatim assembly, 6-vs-7-field quartz assembly, length bound, and `initialValue` accept/reject/reset — driven through observable behavior, not private helpers where avoidable.
