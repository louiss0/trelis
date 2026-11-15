# 08: Reflow an idle TextInput without losing state

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Resize an idle prompt and recover a usable display without requiring a keystroke or changing its draft.

**Blocked by:**
- [07: Keep the TextInput caret usable in narrow viewports](07-narrow-text-input-viewport.md)
- [04: Resolve native TextInput capabilities and restore terminal state](04-native-text-input-capabilities.md)

**Status:** resolved

**Acceptance reference:** [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize), [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail).

- [x] Observe resize changes with supported notifications and bounded fallback, coalescing identical observations.
- [x] Refresh placement safely, preserving logical draft/focus/caret and producing no duplicate history events.
- [x] Handle unknown/zero/transient geometry without guessed cursor placement, lost state or fabricated dimensions.
- [x] Inject watcher/clock/dimension failures and stop all observation resources on supported exits.
- [x] Capture actual prompt repaint/caret scenarios, including native verification as available, rather than only resize arithmetic.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented in commit `e9883be`. Rich TextInput can now observe resize notifications with bounded fallback polling, coalesce unchanged geometry, repaint while idle without mutating draft/caret or transcript history, tolerate invalid and failed observations, and cancel watcher/timer resources on exit. Public resize tests, a Windows caret/restoration probe and limitations—including pending native idle-notification adapter wiring—are recorded in `doc/evidence/trelis-backend/08-idle-text-input-resize.md`.
