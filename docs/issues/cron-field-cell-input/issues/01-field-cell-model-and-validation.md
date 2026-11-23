# 01 Cron field-cell model and validation

Status: resolved

**Blocked by:** none

**What to build:** The internal foundation for field-cell entry, with no UI. Define the per-profile ordered field-cell schema (unix: minute 0-59, hour 0-23, day-of-month 1-31, month 1-12 JAN-DEC, day-of-week 0-7 SUN-SAT with 0 and 7 both Sunday; quartz: second, minute, hour, day-of-month with `?`/`L`/`LW`/`L-n`/`L-nW`/`nW`, month, day-of-week 1-7 with `?`/`L`/`dL`/`d#n`, optional year 1970-2199), per-cell draft validation that returns field-specific errors, the Quartz `?` day-exclusivity rule, verbatim expression assembly (single ASCII space joins; quartz cell 6 empty emits a clean 6-field expression; 4096 UTF-16 code-unit bound including separators), and constructor `initialValue` validation (`ArgumentError` on malformed/out-of-range/padded/wrong-count non-empty values; valid values split into initial cells; every `.prompt()` run resets to them). Empty `initialValue` leaves all cells empty — never silently coerced to `*` or `?`. Reuse the existing `_valid`/`_quartzField`/`_compileQuartzFields` grammar machinery in `lib/src/cron_input.dart` rather than duplicating it. See the [spec](../spec.md) Implementation Decisions: profile-determined field-cell schemas, initial cell state, expression assembly, validation timing.

Prefer placing new code in a new `part` file (e.g. `lib/src/cron_field_cells.dart` added to the `part` list in `lib/src/text_input.dart`) so parallel tickets editing `cron_input.dart` conflict less.

## Acceptance criteria

- [ ] Internal API exposes the ordered field-cell descriptors per `CronProfile` (name, position `i/N`, range cue, optional flag for quartz year) and per-cell validation producing field-specific error messages.
- [ ] Quartz `?` exclusivity is checked after per-field syntax: exactly one of day-of-month and day-of-week cells may be `?`; violations identify the day cells.
- [ ] Assembly joins cells with single ASCII spaces, preserves token spelling/case verbatim, emits 6 fields for quartz when year cell is empty, and enforces the 4096 UTF-16 code-unit limit including separators.
- [ ] Non-empty `initialValue` is validated at construction (`ArgumentError` on failure) and split into initial cells (quartz 6-field paste-style values leave year cell empty); reusable prompts reset cells per invocation.
- [ ] Tests cover unix/quartz schemas, per-field errors, `?` rule, verbatim assembly, 6-vs-7-field quartz assembly, length bound, and `initialValue` accept/reject/reset — driven through observable behavior, not private helpers where avoidable.

## Answer

Implemented the internal field-cell model in a new standalone src library `lib/src/cron_field_cells.dart` (intentionally absent from `package:trelis/trelis.dart`, so the public API is unchanged; it is imported by tests directly, matching the repo's src-seam convention). A standalone library was chosen over a `part of 'text_input.dart'` file because part-file members would have become public API through the `text_input.dart` export, and private members would be untestable; the separate file gives the same merge-conflict isolation the ticket preferred.

- Schema: `cronFieldCells(CronProfile)` returns the ordered `CronFieldCell` descriptors (name, 0-based index, 1-based position, total, range cue, optional flag) — 5 unix cells, 6 required + optional year for quartz.
- Grammar reuse, not duplication: `_quartzField`, `_quartzMonths`, `_quartzWeekdays` moved verbatim from `lib/src/cron_input.dart` to `quartzCronField`, `quartzCronMonths`, `quartzCronWeekdays`; the unix per-field loop and the Quartz `?`/`L`/`LW`/`L-n`/`nW`/`dL`/`d#n` day rules were extracted into `unixCronFieldValid`, `quartzCronDayOfMonthValid`, `quartzCronDayOfWeekValid`. `CronInput._valid` now delegates to `cronExpressionError(profile, value)` (identical accept/reject semantics; `_compileQuartzFields` calls the moved grammar).
- Validation: `cronFieldCellError` gives field-specific per-cell errors; `cronFieldCellsError` runs the spec's ordered whole-draft check (first empty mandatory cell -> first invalid populated cell -> Quartz `?` exclusivity focused on cell 3 -> 4096 UTF-16 bound).
- Assembly: `cronAssembleExpression` joins verbatim with single ASCII spaces, omits an empty quartz year cell (clean 6-field expression), and throws `ArgumentError` on wrong cell count or >4096 UTF-16 code units including separators.
- initialValue: `cronInitialFieldCells` returns all-empty cells for `''`, throws `ArgumentError` for malformed/out-of-range/padded/wrong-count non-empty values, and splits valid values on ASCII space runs (quartz 6-field leaves year empty). `CronInput` computes `_initialFieldCells`/`_initialDraft` at construction (throwing before `_input` is built) and seeds every prompt run from them; the normalized single-space draft is also what `TextInput` and the preview path reset to, so multi-space initialValues now round-trip normalized.
- Tests: `test/cron_field_cells_test.dart` (30 tests) covers schemas, per-field errors, `?` exclusivity ordering, verbatim 5/6/7-field assembly, the length bound, initialValue accept/reject/split, and per-invocation prompt reset.

`dart analyze` clean; `dart test` on the new file plus all six existing cron suites passes (102 tests total across the run).
