# 08 Migrate rich-mode cron suites to the field-cell workflow

Status: claimed

**Blocked by:** [02](02-rich-field-cell-entry.md), [03](03-field-cell-paste.md), [04](04-field-cell-presentation.md), [05](05-component-help-and-escape.md), [06](06-preview-review-stage.md)

**What to build:** Finish the suite migration deferred by ticket 07. Once the rich field-cell editor, paste, presentation, help, and preview-review stages are all merged, update every suite that scripted single-line rich cron entry so it drives the field-cell `Tab` workflow: `component_acceptance_matrix_test.dart`, all 15 `*_theme_acceptance_matrix_test.dart`, `theme_structure_framing_test.dart`, `theme_enclosure_framing_test.dart`, `theme_form_ledger_colon_framing_test.dart`, `theme_heading_framing_test.dart`, `theme_formatted_components_test.dart` (`_textBackedFixtures`), `cron_input_test.dart`, `cron_interaction_conformance_test.dart`, and `cron_workflow_migration_test.dart` (exact list per ticket 07's resolution notes — re-derive if the merged code changed it). See the [spec](../spec.md) Testing Decisions.

## Acceptance criteria

- [ ] Every listed suite drives the field-cell workflow (or explicitly documents why a case stays linear) and passes against the merged integration branch.
- [ ] Coverage asserted by the spec's testing decisions is present across the migrated suites: Tab navigation, direct Enter submit, paste, help, review stage, cancellation layers, narrow geometry, ASCII/Unicode focus markers, resize and shared-session repaint where applicable.
- [ ] `dart analyze` clean; full `dart test` green.
