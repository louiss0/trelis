# 19: Migrate Confirm, Checkbox and Toggle

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use the boolean prompts on the shared backend with truthful defaults, controls and completion.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat).

- [x] Preserve bool results, initial/default draft meaning and kind-specific rich gestures.
- [x] Retain linear yes/no/empty-default and command/literal rules.
- [x] Provide compact actions and full stage-aware help without hiding protected state.
- [x] Verify session/profile/colour forwarding, standalone behavior and explicit terminal outcomes.
- [x] Exercise foreground editing with live feedback through public rich/linear tasks.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-19-boolean` in commits `f29e3373adf9bed8d541a24a25fa7b3300be6b1a` and `b67c7e3ff69ae0de11d94f6c13aacf07c416e620`, merged to integration as `fe8e67bb85974ac74747ddd4f694e8863d23ade2`. Confirm, Checkbox and Toggle now use the profile-aware shared backend: their public prompt methods accept terminal, output-profile and session invocation, retain Boolean result/default/draft/control semantics, and support an optional component-local colour theme. Rich and linear help describes applicable controls, defaults and exact command/literal rules. A public TerminalSession scenario keeps a Toggle foreground draft usable while a Spinner emits live feedback.

On Windows with Dart SDK 3.13.2, targeted Boolean/component-matrix/session tests passed 159 tests, `dart analyze` reported no issues, and the full suite passed 698 tests. Evidence and limitations are recorded in `assets/evidence/trelis-backend/19-boolean-migration.md`; native PTY, visible GUI/NVDA, Linux/macOS CI, resize/modal/fault-path and final-gate verification remain outstanding.
