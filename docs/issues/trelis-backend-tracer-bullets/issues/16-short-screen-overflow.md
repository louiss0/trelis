# 16: Preserve the prompt and important notices on short screens

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use a small shared terminal without background feedback hiding the question or silently discarding a failure.

**Blocked by:**
- [14: Support multiple feedback regions with correct lifecycles](14-multiple-feedback-lifecycles.md)

**Status:** resolved

**Acceptance reference:** [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize), [B-SESSION](../../trelis-backend-implementation/spec.md#b-session), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Allocate space to the active prompt/caret and essential context before feedback ornament.
- [x] Compact running feedback into truthful labelled/grouped summaries while keeping registration order stable.
- [x] Emit important warnings/errors/outcomes in full reviewable history and retain relevant visible severity indicators.
- [x] Avoid introducing session scrolling keys that collide with prompt controls or silently changing interaction mode.
- [x] Verify narrow/short/zero geometry combinations, resize recovery and event idempotence with actual composed views.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-16-short-screen` in commits `df3cac707da45a75ce2f6928145b1f4002bb6b2a`, `ca881db7f058cfaa7dee26989161c894d4775571`, and `54947ecd0222cd8333cb58605e3a256610e6a5a0`, merged to integration as `aae33d028c4d097845b95aeaefe8bce4db6c2d6e`. `TerminalSession` now reserves the active editable prompt row before allocating feedback space and emits a width-bounded, registration-order-preserving `Feedback (n)` summary when live feedback exceeds remaining geometry. One-row compositions retain the prompt/caret; warnings, errors, and explicit outcomes remain full reviewable records with severity indication. No scrolling controls or interaction modes were added. Evidence is in `doc/evidence/trelis-backend/16-short-screen-overflow.md`.

Verification on Windows with Dart SDK 3.13.2: focused short-screen/session/help/resize tests passed 12 tests, `dart analyze` reported no issues, and the full suite passed 704 tests at the implementation revision. Native terminal repaint/scrollback, font-width behavior, GUI/NVDA, Linux/macOS CI, writer fault injection and final-gate evidence remain limitations.
