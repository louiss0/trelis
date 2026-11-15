# 25: Migrate DateInput and TimeInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Edit civil dates and times with incomplete fields, correct format context and real field-local caret placement.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-MEASURE](../../trelis-backend-implementation/spec.md#b-measure), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize).

- [x] Preserve calendar/order/digits/era, time format and adjustment/bounds semantics without normalizing incomplete drafts into final values.
- [x] Retain Edit/Review/Submit stages, logical field order and actual primary actions.
- [x] Provide full component help, minimal active-format cues and required interpretation/review content.
- [x] Exercise inline/stacked layouts, clipping, idle resize and help while feedback updates.
- [x] Verify public typed results and cancellation/interruption/EOF/validation in both modes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Merged to integration as `fca342b`, followed by `1ba0511` to reconcile two prose assertions with ticket 21's wrapping behavior (whitespace-insensitive comparison; no product-code change). Post-merge verification: 151 targeted tests and 736 full-suite tests passed; analysis, changed-test formatting and documentation links passed. Native/GUI/cross-platform evidence remains pending.

## Answer

Implemented on `ticket/backend-25-date-time` in commits `180bd97` (wrapped guidance and idle-resize repaint), `444e86d` (stage-led help and outcome coverage), `8b281ec` (README and shared helper placement) and `6f03247` (evidence), based on integration `9d6ecbe` merged as `1413196`; the integration tip was unchanged when the branch was re-merged before this report. `DateInput` and `TimeInput` now resolve the invocation/source/legacy output-profile precedence, refuse an explicitly requested rich mode the profile cannot support, apply `NO_COLOR`, and accept `terminal`, `outputProfile` and `session`. An attached prompt inherits its session input, output and profile, reads the session-owned key stream and repaints through the session writer, while ticket 17's shared-writer failure handling and resize-failure delivery stay intact.

`TimeInput` no longer delegates to `TextInput`: it edits labeled hour/minute/second/period fields as local drafts with per-field adjustment bounds and no carry, keeps the Edit-formatted and Submit actions, and reports the time-of-day interpretation at review. `DateInput` keeps its three segment drafts, review interpretation with the ISO spelling, and explicit `/submit`/`/edit` actions. Both prompts wrap every guidance line within the declared geometry, terminate the editable line left open by a control action so guidance never overwrites the field the user just left, and repaint the active editor on an idle resize without changing the draft. Component help (Ctrl+T, `/help`) leads with the requesting stage — focused field, review, formatted entry or submit — and keeps the accepted format, digits, calendar, interpretation and workflow in the same block; errors keep the offending field, width, repertoire and calendar range visible.

On Windows 11 (`10.0.26200`) with Dart SDK 3.13.2, the date/time suites plus the new migration suite passed 31 tests, the component acceptance matrix passed 144 tests, `dart analyze` reported no issues, the documentation-link check passed 152 links in 43 files, and the full suite passed 724 tests at revision `8b281ec`. Evidence, source revision, environment, commands, expected/actual results and limitations are recorded in `doc/evidence/trelis-backend/25-date-time-migration.md`.

Limitations: this is scripted public-behavior evidence only. Native PTY, Linux/macOS CI, visible-terminal GUI/NVDA, alternate-screen modal help for this family and the final evidence gate remain outstanding, the resize-notification stream must support repeated listens per prompt, wrapping splits at display cells rather than word boundaries, these prompts still have no `ColorTheme` argument, and three unrelated test files already failed the repository-wide format check on the integration tip.
