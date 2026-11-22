# 15: Make help modal while background work keeps updating

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Read full prompt help while feedback work continues, then return to the latest shared display.

**Blocked by:**
- [14: Support multiple feedback regions with correct lifecycles](14-multiple-feedback-lifecycles.md)

**Status:** resolved

**Acceptance reference:** [B-MODAL](../../trelis-backend-implementation/spec.md#b-modal), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail).

- [x] Coordinate a single session-modal view and alternate-screen transition rather than letting regions paint independently.
- [x] Retain latest background snapshots and all significant notices while ordinary painting is paused.
- [x] Restore current valid prompt state and the latest feedback, not a screenshot from help entry.
- [x] Exercise unsupported-screen transcript fallback and interruption/EOF/errors without losing input or cleanup.
- [x] Verify help routes remain truthful and do not imply new capture/literal commands.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-15-modal-help` in commits `fd20fd69496c38728f416d76d5adbd34ff8bfbf8` and `07f500423cd06f1c2a436c7f676e865f6487d7b9`, merged to integration as `1ff7f95b89276d0e33ed82a41db5ab813abaf005`. `TerminalSession` now owns rich and transcript modal-help painting, retains latest feedback snapshots and coordinated notices while help is active, and restores current snapshots before repainting the valid prompt draft/caret. Public scripted scenarios cover alternate-screen dismissal after concurrent Spinner/Text updates, unsupported-screen transcript fallback with interruption, and alternate-screen release plus retained notices on EOF and session errors. Evidence is in `assets/evidence/trelis-backend/15-modal-help-live-jobs.md`.

Verification on Windows with Dart SDK 3.13.2: focused modal tests passed 3 tests, `dart analyze` reported no issues, and the full suite passed 701 tests. Native PTY/visual alternate-screen behavior, screen-reader testing, writer fault injection, Linux/macOS CI, Windows GUI and final-gate evidence remain limitations.
