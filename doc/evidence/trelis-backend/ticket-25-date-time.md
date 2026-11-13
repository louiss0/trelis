# Ticket 25 — DateInput and TimeInput migration evidence

- **Source revision:** recorded after commit as the ticket branch HEAD.
- **Date/environment:** 2026-11-12; Windows; Dart commands run from the ticket worktree.
- **Public seam:** `DateInput.prompt` and `TimeInput.prompt`, including `TerminalSession.run`, `ScriptedInput`, `OutputProfile`, typed `PromptResult` outcomes, and emitted presentation text.

## Executed verification

1. `dart test test/date_time_migration_test.dart --reporter expanded` passed 3 tests. It covered incomplete rich time fields through explicit submit/review text, date editing in a rich session while a Spinner updated, rich Ctrl+T help and linear `/help` plus cancellation.
2. `dart test` date/time component suites passed 28 DateInput tests and 12 TimeInput tests. The suites cover calendar/order/digit/era conversion, field-local navigation and adjustment, retained invalid drafts, explicit review actions, format validation, defaults, cancellation/interruption/EOF, and rich capability refusal.
3. Full formatting, analysis, and the full Dart test suite are recorded in the commit-validation command output.

## Result and limitations

DateInput and TimeInput now resolve declared output profiles, reject unsupported requested rich interaction, inherit explicit session configuration, and use the session-owned key stream. Rich editing uses field-local `_edit` regions, preserving incomplete field drafts; TimeInput now exposes individual time fields before formatted edit/submit. Both components expose active-format cues and stage-specific rich/linear help.

This is automated scripted-output evidence only. It is not native Windows terminal, Linux/macOS CI, visible-terminal GUI, font/width-policy, or screen-reader evidence; those remain pending the later platform and evidence-gate tickets.
