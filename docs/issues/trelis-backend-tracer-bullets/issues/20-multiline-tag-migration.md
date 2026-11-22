# 20: Migrate Multiline and TagInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Edit multiline answers and tag collections with distinct add/newline versus finish actions on the shared backend.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-MEASURE](../../trelis-backend-implementation/spec.md#b-measure).

- [x] Preserve hard line breaks, supported literal tabs, limits, validation and multiline edit/insert/remove/review behavior.
- [x] Keep draft tags separate from accepted tags with correct casing, duplicate and edit/remove rules.
- [x] Provide complete current-stage help and truthful primary-action hints rather than generic text-submit wording.
- [x] Verify caret/focus, resize and help restoration while feedback updates.
- [x] Retain public result/EOF/cancel/interrupt and invocation compatibility in both modes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Merged into integration as `9aa373a`. The sole text conflict was the semantically identical shared linear-help precedence change from tickets 20/21; retained the existing single chain. Post-merge: 760 full-suite tests passed, targeted multiline/tag/selection/session suites passed, analysis and changed-file formatting clean, documentation links passed. Native/GUI/cross-platform gates remain pending.

## Answer

Implemented on `ticket/backend-20-multiline-tags` in commits `3e0d59a93b7884be7c76900124a0fb35ee41c83f` (code and tests) and `3784db5bc315fdc8db54996b6389a49caea33c2b` (evidence), branched from integration tip `9d6ecbe`. Not merged into integration. `Multiline` and `TagInput` now accept `terminal`, `outputProfile` and `session` invocation on the same terms as the migrated editor, resolve rich mode from the declared profile instead of the legacy rich hint, render inside the declared width with truthful overflow markers, and keep component-specific current-stage help (`Ctrl+T`/`/help`) that names the add-newline, finish, insert-tab, add-tag, focus, edit, remove and discard actions plus limits and caller validation. Multiline keeps its own buffer loop (vertical navigation, Tab actions, literal tab insertion, edit/insert/remove/review) and gains session repaint registration, idle-resize reflow and session-owned modal help that restores the latest status, draft and caret. TagInput forwards the resolved profile, resize observer and session to the shared editor, so the unaccepted draft stays visibly separate from accepted tags across repaints.

On Windows with Dart SDK 3.13.2, the new `test/multiline_tag_migration_test.dart` passed 14 tests, the Multiline/TagInput suites passed 63 tests, the Multiline/TagInput/component-matrix suites passed 207 tests, `dart analyze` reported no issues, `dart run tool/check_doc_links.dart` checked 152 links in 43 files, and the full suite passed 728 tests against a measured 714-test base with no existing test removed. Evidence, migration notes and limitations are in `assets/evidence/trelis-backend/20-multiline-tag-migration.md`; native PTY, visible GUI/NVDA, Linux/macOS CI, fault-injection and final-gate verification remain outstanding in tickets 31–33.
