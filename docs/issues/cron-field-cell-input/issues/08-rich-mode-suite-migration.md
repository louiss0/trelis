# 08 Migrate rich-mode cron suites to the field-cell workflow

Status: resolved

**Resolution notes (ticket 08):**

- Audited every suite ticket 07 deferred against the merged field-cell code. Ticket 02 had already migrated the acceptance-matrix and framing fixtures (`component_acceptance_matrix_test.dart`, all 15 `*_theme_acceptance_matrix_test.dart` via `theme_matrix_cases.dart` `richAnswer`, `theme_structure_framing_test.dart`, `theme_enclosure_framing_test.dart`, `theme_form_ledger_colon_framing_test.dart`, `theme_heading_framing_test.dart`, and `theme_formatted_components_test.dart` `_textBackedFixtures`) to the Tab-separated cell workflow; `cron_input_test.dart`, `cron_interaction_conformance_test.dart` (preview-cancellation case) and `cron_workflow_migration_test.dart` were likewise already on cell scripts.
- Three stragglers still scripted single-line rich entry and were migrated: `cron_interaction_conformance_test.dart` `rich review interruption does not accept a draft` (`'* * * * *\r\x03'` -> `'*\t*\t*\t*\t*\r\x03'`), and `cron_workflow_migration_test.dart` (`'* * * * *\r'` -> Tab script in the undeclared-output refusal case; `'* * *\x14\x1b\x03'` -> `'*\x14\x1b\x03'` so help still leads with the focused minute cell).
- Coverage audit of the spec Testing Decisions found two genuine gaps, filled without duplicating the dedicated suites: quartz 7-cell ring wraparound through the year cell and trailing `Submit` back to cell 0 (`cron_field_cells_entry_test.dart`), and narrow-geometry whole-cell wrapping at 40 columns across the rail/box/round/double structural themes (`cron_field_cell_presentation_test.dart`). Every other spec bullet — Tab/Shift-Tab/Ctrl+B navigation, Enter-from-cell submit, paste, help invariance, review stage, cancellation layers, ASCII/Unicode focus markers, idle resize repaint, shared-session feedback coexistence, and linear/screen-reader parity — was already asserted by tickets 02-07's suites.
- No `lib/` changes were needed; no spec violations surfaced.

**Blocked by:** [02](02-rich-field-cell-entry.md), [03](03-field-cell-paste.md), [04](04-field-cell-presentation.md), [05](05-component-help-and-escape.md), [06](06-preview-review-stage.md)

**What to build:** Finish the suite migration deferred by ticket 07. Once the rich field-cell editor, paste, presentation, help, and preview-review stages are all merged, update every suite that scripted single-line rich cron entry so it drives the field-cell `Tab` workflow: `component_acceptance_matrix_test.dart`, all 15 `*_theme_acceptance_matrix_test.dart`, `theme_structure_framing_test.dart`, `theme_enclosure_framing_test.dart`, `theme_form_ledger_colon_framing_test.dart`, `theme_heading_framing_test.dart`, `theme_formatted_components_test.dart` (`_textBackedFixtures`), `cron_input_test.dart`, `cron_interaction_conformance_test.dart`, and `cron_workflow_migration_test.dart` (exact list per ticket 07's resolution notes — re-derive if the merged code changed it). See the [spec](../spec.md) Testing Decisions.

## Acceptance criteria

- [x] Every listed suite drives the field-cell workflow (or explicitly documents why a case stays linear) and passes against the merged integration branch.
- [x] Coverage asserted by the spec's testing decisions is present across the migrated suites: Tab navigation, direct Enter submit, paste, help, review stage, cancellation layers, narrow geometry, ASCII/Unicode focus markers, resize and shared-session repaint where applicable.
- [x] `dart analyze` clean; full `dart test` green.

## Answer

Final coverage pass complete; every suite ticket 07 deferred now drives the field-cell `Tab` workflow and the spec's testing decisions are fully covered. No `lib/` changes and no public API changes.

- Already migrated by ticket 02 (verified, unchanged): `component_acceptance_matrix_test.dart`, all 15 `*_theme_acceptance_matrix_test.dart` (via the shared `theme_matrix_cases.dart` `richAnswer` fixture), `theme_structure_framing_test.dart` (Rail/Branch runners), `theme_enclosure_framing_test.dart`, `theme_form_ledger_colon_framing_test.dart`, `theme_heading_framing_test.dart`, `theme_formatted_components_test.dart` (`_textBackedFixtures`), plus the rich legs of `cron_input_test.dart`, `cron_interaction_conformance_test.dart` and `cron_workflow_migration_test.dart`.
- Migrated in this ticket (the only remaining single-line rich scripts): `test/cron_interaction_conformance_test.dart` — `rich review interruption does not accept a draft` now scripts `'*\t*\t*\t*\t*\r\x03'`; `test/cron_workflow_migration_test.dart` — the undeclared-output refusal case scripts the Tab cell sequence (input is never consumed, but stays consistent) and `cron rich entry help leads with the dialect and its limits` scripts `'*\x14\x1b\x03'` so help still leads with the focused minute cell.
- New coverage filling genuine spec gaps: `test/cron_field_cells_entry_test.dart` — quartz 7-cell `Tab` wraparound through the year cell and trailing `Submit` back to cell 0; `test/cron_field_cell_presentation_test.dart` — whole-cell wrapping at 40 columns inside the rail, box, round and double structural themes with per-line width and no mid-cell breaks.
- Already covered by tickets 03-07 suites (verified, not duplicated): paste distribution/rejection, stage-led help and snapshot invariance, review-stage Edit/Preview/Submit and Escape layering, ASCII `[> <]` vs Unicode `[→ ←]` focus markers, protected cue under hidden instructions, idle-resize repaint, shared-session spinner coexistence, and linear/screen-reader parity.
- Verified: `dart pub get`, `dart analyze` clean, full `dart test` green (5693 tests).
