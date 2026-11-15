# Implement the explicit shared session and multi-region compositor
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 04, 05
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Implement TerminalSession.run/session attachment and a single writer composing synthetic live regions with one active prompt slot plus feedback.

## Acceptance

- [B-SESSION](../spec.md#b-session)
- [B-RESIZE](../spec.md#b-resize)
- [B-MODAL](../spec.md#b-modal)
- [B-FAIL](../spec.md#b-fail)

- [ ] Implement scoped configuration inheritance, ownership conflict errors, closed handles and standalone temporary-session adapters without automatic joining.
- [ ] Use stable feedback registration order above the prompt, actual frame/caret restoration and coalesced idle resize observation.
- [ ] Implement prompt-priority height allocation, important-history preservation and coordinated informational messages.
- [ ] Coordinate session-modal help/alternate screen while background state changes; restore latest state and preserve meaningful notices.
- [ ] Isolate region faults, close on shared writer failure, drain/dispose and restore on callback/prompt exits without fabricating job outcomes.

## Evidence required

Deterministic compositor tests with resize, modal updates, local/global failures and teardown before real component migration.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
