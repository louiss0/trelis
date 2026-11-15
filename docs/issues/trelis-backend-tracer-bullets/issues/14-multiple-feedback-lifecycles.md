# 14: Support multiple feedback regions with correct lifecycles

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Watch several Spinners, Progress and MultiSpinner update independently while the prompt remains usable.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-FEEDBACK](../../trelis-backend-implementation/spec.md#b-feedback), [B-SESSION](../../trelis-backend-implementation/spec.md#b-session), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Integrate public feedback lifecycles, stable registration/removal and coordinated outcome commits into the session.
- [x] Preserve milestone/time/phase/recalculation behavior and fake-clock determinism; rendering does not own cadence.
- [x] Keep reaching a total, disposal and scope exit distinct from explicit completed/failed/cancelled outcomes.
- [x] Retain MultiSpinner's real all-task completion behavior and prevent stale/retired updates from reviving output.
- [x] Exercise multiple producers, unfinished disposal and prompt-caret preservation in both output modes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-14-feedback-lifecycles` in `bbccf1046ec27a62a47c6bb650872f8f9d452695`, with final evidence commit `0a3c8f800aea2c685eaef952f69b9adfe93bc61b`, merged to integration as `be156195f9a09504c34505a0e6fc5c091568cd66`. Progress and MultiSpinner now accept the public `FeedbackClock` cadence seam, preserving default timer behavior while allowing deterministic application-controlled scheduling. Public rich and linear `TerminalSession` scenarios exercise Spinner, Progress, MultiSpinner and an active TextInput together; they preserve the `demo` draft/caret, retain explicit outcomes, prevent totals/disposal/scope exit from manufacturing success, preserve MultiSpinner’s all-task summary, and reject stale retired updates. Evidence is recorded in `doc/evidence/trelis-backend/14-multiple-feedback-lifecycles.md`.

Verification on Windows with Dart SDK 3.13.2: targeted feedback/session tests passed 25 tests, `dart analyze` reported no issues, documentation links checked 152 links, formatting was clean, and the full `dart test --reporter expanded` suite passed 691 tests. Evidence remains scripted/public only; native PTY, visible GUI, modal-help, short-height/resize, Linux/macOS CI and final-gate evidence remain limitations.
