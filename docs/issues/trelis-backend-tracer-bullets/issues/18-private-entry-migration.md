# 18: Migrate Password and URLInput without private-state leakage

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use private-entry components inside the shared backend without exposing drafts through rendering, history or help.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Integrate actual hidden/masked fields, stage actions and generic secret-validation behavior with session/profile invocation.
- [x] Keep raw private values and undisclosed length/caret metadata out of layout, diagnostics and output; use synthetic canaries only.
- [x] Preserve explicit masking/prefill disclosure warnings and safe non-text help routes without turning literal data into commands.
- [x] Retain URL draft hiding and its component-approved accepted interpretation; do not claim universal query/path redaction.
- [x] Verify all applicable public outcomes, help/review restoration and background repaint interactions in rich/linear modes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-18-private-entry` in commit `6b79eaa196ae19405e41a679c7bd5441e86604f5`, merged to integration as `89493e19e8fdad58935906adf0acbeeb71af081c`. Password and URLInput now run through explicit `TerminalSession` and profile invocation. Private drafts, caret/length metadata, paste provenance, validation canaries, and URL path/query text remain outside presentation output and transcript history; masking and prefill disclosures remain explicit. Password stage actions and help stay separate from literal secret input, while URLInput retains only its approved host interpretation. Public rich/linear scenarios include shared feedback repaint interactions.

Verification on Windows with the repository Dart SDK: targeted password, URL and session-feedback tests passed 24 tests; `dart analyze` reported no issues; the full test suite passed before commit. Evidence and limitations are recorded in `doc/evidence/trelis-backend/18-private-entry-migration.md`; native PTY, visible GUI, Linux/macOS CI and final-gate qualification remain outstanding.
