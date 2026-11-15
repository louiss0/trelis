# 13: Run a prompt alongside one Spinner and coordinated Text messages

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Answer TextInput while a Spinner and informational messages share its output without overwriting the caret.

**Blocked by:**
- [12: Run sequential TextInput prompts in an explicit scoped session](12-scoped-sequential-text-input.md)
- [08: Reflow an idle TextInput without losing state](08-idle-text-input-resize.md)
- [11: Provide compact and full TextInput help safely](11-text-input-help.md)
- [09: Apply capability-aware colours to TextInput](09-text-input-colour-rendering.md)

**Status:** resolved

**Acceptance reference:** [B-SESSION](../../trelis-backend-implementation/spec.md#b-session), [B-FEEDBACK](../../trelis-backend-implementation/spec.md#b-feedback), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Integrate actual Spinner and Text invocation with explicit sessions and supported standalone ownership rules.
- [x] Use one serialized writer, typed region identity and a stable status-above-prompt arrangement.
- [x] Preserve logical caret/draft through status changes and coordinated messages, including profile/palette choices and resize.
- [x] Reject independent conflicting screen owners instead of silently creating a global shared screen.
- [x] Verify rich/linear public scenarios and safe basic help coordination without manufacturing outcomes or consuming input in feedback.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-13-prompt-live-status` in commit `70f1c0334fcbd9619300979a233a5611d50a8fde`, merged to the integration branch as `c6df5687a0419f902ada0961650290e6efe14157`. `TerminalSession` now coordinates attached Spinner, Progress, MultiSpinner and Text output through typed, generation-checked feedback registrations. Rich feedback clears and repaints the active TextInput line from its logical state, preserving its transcript draft/caret while status and informational messages arrive. Attached feedback inherits the session output/profile/mode and rejects competing configuration; independent sessions targeting an owned output are rejected rather than becoming an implicit global screen. Explicit feedback outcomes retire only presentation regions and disposal does not invent job outcomes. Public scripted rich-session verification and evidence are in `test/terminal_session_feedback_test.dart` and `doc/evidence/trelis-backend/13-prompt-live-status.md`.

Verification on Windows/Dart repository SDK after merge: `dart test test/terminal_session_feedback_test.dart` passed, `dart analyze` reported no issues, and the full `dart test` suite passed 687 tests. Evidence is scripted/public only; native PTY, GUI, resize/short-height, modal-help and Linux/macOS CI remain final-gate limitations.
