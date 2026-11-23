# 07 Linear interaction parity and suite migration

Status: ready-for-agent

**Blocked by:** [01](01-field-cell-model-and-validation.md)

**What to build:** Preserve and verify the linear/screen-reader contract for the new field-cell `CronInput`. Linear interaction continues to accept the complete space-separated cron expression on a single command-aware entry line (`/help`, `/cancel`, backslash command quoting, identified paste as literal entry, `/preview`, `/edit`, `/submit` during review), validating against the same 5-field unix and 6-or-7-field quartz rules via the ticket-01 model — invalid drafts retained for correction. Screen-reader presentation resolves to linear with concise essential context presented before the prompt. Update existing compatibility and structural-theme acceptance-matrix suites whose scripted rich-mode inputs assumed single-line cron entry so they drive the new field-cell `Tab` workflow cleanly (see spec Testing Decisions: prior art suites to follow). See the [spec](../spec.md) Implementation Decisions: preview stage/cancellation layers and linear interaction; user stories 29 and testing bullet on suite migration.

## Acceptance criteria

- [ ] Linear mode accepts full expressions with identical validation outcomes to rich mode, retains invalid drafts, and supports the documented command set including review-stage commands.
- [ ] Screen-reader/linear presentation emits concise essential context before the prompt.
- [ ] Existing cron conformance/workflow/matrix suites are updated to the field-cell workflow and pass; no public API signatures change.
- [ ] Tests assert parity of accepted `CronExpression`/`CronPreview` results across modes through the public seam.
