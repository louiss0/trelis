# 06 Preview Review stage on field cells

Status: resolved

**Blocked by:** [02](02-rich-field-cell-entry.md), [05](05-component-help-and-escape.md)

**What to build:** Rework the `CronPreviewConfig` Review stage so it composes with field cells. Valid submission from any cell or the trailing `Review` stop enters `Review` offering `Edit`, `Preview`, `Submit` (rich: Tab/Shift-Tab + Enter; linear: `/edit`, `/preview`, `/submit`). `Edit` returns focus to cell 0 with all cell drafts preserved verbatim. `Preview` computes the bounded **cron matching preview** and reports status/instants; `Submit` accepts the `CronExpression` assembled from the cells. Escape layering completes the spec: in rich interaction `Escape` cancels only an in-flight preview and returns to `Review` with the retained draft; a further `Escape` (outside help) cancels the prompt; `Ctrl+C` interrupts from every layer including during preview calculation; linear `/cancel` mirrors this (first `/cancel` stops the preview, second ends the prompt). Review help (via `Ctrl+T`/`/help`) leads with the Review stage's controls per ticket 05. See the [spec](../spec.md) Implementation Decisions: preview stage, cancellation layers, and linear interaction; user stories 24-26.

## Acceptance criteria

- [ ] With `preview != null`, valid entry reaches Review; `Edit` round-trips to cell 0 with drafts intact; `Preview` reports bounded instants/status; `Submit` accepts the assembled `CronExpression`.
- [ ] Escape/`/cancel` during an in-flight preview returns to Review with the draft retained; a second cancel ends the prompt; `Ctrl+C` interrupts everywhere.
- [ ] Quartz 6-field (blank year) and 7-field drafts preview correctly, including year-bounded matching.
- [ ] Tests cover the Review workflow, preview cancellation layering, and Edit round-trip through the public seam, including slow-preview cancellation.

## Answer

The Review stage already composed with field cells from tickets 02/05/07 (`_fieldCells` returns the assembled draft on valid submit and `_reviewStage` offers Edit/Preview/Submit in both modes); this ticket verified the composition end-to-end, closed the help-ordering gap, and added the missing public-seam coverage.

- `_reviewHelp` now places the stage controls (`/preview`, `/edit`, `/submit` in linear; `Edit, Preview and Submit` action navigation in rich) immediately after the stage lead and before the field-order map, matching ticket 05's stage-led help convention.
- `test/cron_field_cells_review_test.dart` (6 tests, all through `CronInput.prompt` + `ScriptedInput`):
  - Quartz blank-year draft (`0 0 0 * * ?`) entered cell-by-cell previews matching instants on both sides of a year boundary and submits the clean six-field expression.
  - Quartz populated year cell (`0 0 0 * * ? 2023`) bounds the preview to the declared year — the 2024 instant inside the window is absent while the 2023 instant is reported.
  - Rich `Escape` during a slow in-flight preview (budget-bound unmatchable draft, driven by a live `StreamController`) reports `Matching preview: cancelled`, returns to Review with the draft retained and focus preserved, and Submit then accepts `0 0 31 2 *`.
  - Rich `Ctrl+C` during the same slow preview returns `Interrupted`.
  - `Escape` outside any preview still cancels the rich review prompt.
  - Review help (`Ctrl+T` inside Review) leads with the stage controls ahead of `Field order:`.
- Pre-existing coverage confirmed unchanged: linear `/cancel` preview layering (`cron_interaction_conformance_test.dart`, `cron_linear_parity_test.dart`), rich preview-cancel-then-cancel, Edit round-trips, and review help content (`cron_workflow_migration_test.dart`, `cron_field_cells_help_test.dart`, `cron_field_cells_entry_test.dart`).
- Verified: `dart pub get`, `dart analyze` clean, `dart format` clean, full `dart test` green (5682 tests). Integration tip `1cd5f09` (tickets 01/02/03/05/07 merged) was the branch base; ticket 04 remains in flight on its own branch and did not conflict — the only `lib/` change is the `_reviewHelp` sentence order plus `dart format` normalization of two ticket-03 return records.
