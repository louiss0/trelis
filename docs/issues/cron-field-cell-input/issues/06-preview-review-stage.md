# 06 Preview Review stage on field cells

Status: ready-for-agent

**Blocked by:** [02](02-rich-field-cell-entry.md), [05](05-component-help-and-escape.md)

**What to build:** Rework the `CronPreviewConfig` Review stage so it composes with field cells. Valid submission from any cell or the trailing `Review` stop enters `Review` offering `Edit`, `Preview`, `Submit` (rich: Tab/Shift-Tab + Enter; linear: `/edit`, `/preview`, `/submit`). `Edit` returns focus to cell 0 with all cell drafts preserved verbatim. `Preview` computes the bounded **cron matching preview** and reports status/instants; `Submit` accepts the `CronExpression` assembled from the cells. Escape layering completes the spec: in rich interaction `Escape` cancels only an in-flight preview and returns to `Review` with the retained draft; a further `Escape` (outside help) cancels the prompt; `Ctrl+C` interrupts from every layer including during preview calculation; linear `/cancel` mirrors this (first `/cancel` stops the preview, second ends the prompt). Review help (via `Ctrl+T`/`/help`) leads with the Review stage's controls per ticket 05. See the [spec](../spec.md) Implementation Decisions: preview stage, cancellation layers, and linear interaction; user stories 24-26.

## Acceptance criteria

- [ ] With `preview != null`, valid entry reaches Review; `Edit` round-trips to cell 0 with drafts intact; `Preview` reports bounded instants/status; `Submit` accepts the assembled `CronExpression`.
- [ ] Escape/`/cancel` during an in-flight preview returns to Review with the draft retained; a second cancel ends the prompt; `Ctrl+C` interrupts everywhere.
- [ ] Quartz 6-field (blank year) and 7-field drafts preview correctly, including year-bounded matching.
- [ ] Tests cover the Review workflow, preview cancellation layering, and Edit round-trip through the public seam, including slow-preview cancellation.
