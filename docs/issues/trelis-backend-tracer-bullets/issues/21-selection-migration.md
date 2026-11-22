# 21: Migrate Select, Radio and MultiSelect

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Choose one or many values through typed shared regions without changing choice identity or selection rules.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-RENDER](../../trelis-backend-implementation/spec.md#b-render).

- [x] Preserve concrete generic result types, defaults, limits and disabled-choice acceptance rules.
- [x] Keep focus, checked/selected, default and unavailable state separate with stable displayed references/pages.
- [x] Retain filter/select-visible/clear-visible/selected-review and completion workflow as applicable.
- [x] Provide reusable typed choice presentation exercised by actual public prompts, with complete help and protected reasons.
- [x] Verify rich/linear tasks, overflow, repeated errors and all terminal outcomes without structure-specific input loops.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Merged into `integration/trelis-backend-tracer-bullets` as `10de1bc8c03c7a0901956bfcd2f967dac615cb6c` (no conflicts). Post-merge verification: 726 full-suite tests passed, analysis and changed-file formatting clean, documentation links passed. Tickets 22, 23 and 27 are now unblocked; native/GUI/cross-platform gates remain pending.

## Answer

Implemented on `ticket/backend-21-selection` in commits `fd465bf` (implementation) and `6beacb2` (evidence), merged with integration `9d6ecbe` as `e11b9a5`. `Select`, `Radio` and `MultiSelect` now compose rows through one typed choice presentation, so a stable reference and the selection, focus, displayed-default and unavailable-reason facts stay separate; state markers are atomic units that narrow declared widths wrap around rather than split. Component help is complete for the current stage (reference entry, toggle, filter, bulk, review, paging, bounds and exact command rules) and names every unavailable reason, including paged-away or filtered-away choices, while help dismissal repaints the retained focus and draft. Warnings, acceptance, toggle, review and bound messages wrap within the declared width and use the component palette when the effective profile permits colour. The prompts accept `terminal`, `outputProfile`, `session` and an optional `ColorTheme`, honour `NO_COLOR`, restore acquired leases and keep a foreground draft usable while session feedback repaints. Supplied answers, generic results, defaults, limits and every terminal outcome keep their previous rules.

On Windows (NT 10.0.26200.0) with Dart SDK 3.13.2, targeted selection tests passed 32 tests, component-matrix/session/failure-recovery suites passed 157 tests, `dart analyze` reported no issues, the documentation-link check passed, and the full suite passed 726 tests at revision `e11b9a5`. Evidence and limitations are recorded in `assets/evidence/trelis-backend/21-selection-migration.md`; native PTY, visible GUI/NVDA, Linux/macOS CI, short-screen resize, modal-help, fault-injection and final-gate verification remain outstanding, and rich vertical overflow is verified only as transcript scrollback.
