# 12: Run sequential TextInput prompts in an explicit scoped session

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Ask successive questions through one explicit TerminalSession without losing scripted input or hiding configuration ownership.

**Blocked by:**
- [10: Emit meaningful linear TextInput history](10-linear-text-input-events.md)
- [04: Resolve native TextInput capabilities and restore terminal state](04-native-text-input-capabilities.md)

**Status:** resolved

**Acceptance reference:** [B-SESSION](../../trelis-backend-implementation/spec.md#b-session), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event), [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat).

- [x] Expose the approved scoped run and invocation attachment interface with inherited source/output/mode/profile and clear conflicting-setting errors.
- [x] Acquire native input lazily and preserve feedback-only/no-input behavior for the upcoming region integration.
- [x] Keep one session-owned scripted reader/router across prompts without closing/resubscribing or losing buffered data/provenance.
- [x] Reject a second active prompt before consuming input and preserve existing physical-input exclusivity.
- [x] Verify standalone temporary-session behavior, normal callback results/errors, lease cleanup and closed-handle rejection.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-12-scoped-session` in commits `eaac422` and `2c967fd`, then refreshed against integration in `377be5b`. `TerminalSession.run` provides a scoped public owner and `TextInput.prompt(session:)` attaches with inherited configuration and explicit conflict errors. Sequential prompts share one session-owned input router, overlapping prompts are rejected before consuming input, acquisition remains lazy, callback failures propagate, leases clean up and closed handles reject new work. Evidence is recorded in `doc/evidence/trelis-backend/ticket-12-scoped-session.md`.
