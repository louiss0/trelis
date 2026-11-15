# Integrate Text, Progress, Spinner and MultiSpinner as coordinated feedback
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 06
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Move the four existing feedback components to the shared session/render/event path while preserving their separate lifecycle semantics.

## Acceptance

- [B-FEEDBACK](../spec.md#b-feedback)
- [B-SESSION](../spec.md#b-session)
- [B-EVENT](../spec.md#b-event)

- [ ] Add session/outputProfile invocation options with conflict validation and retain standalone start/present behavior.
- [ ] Preserve progress milestone/time/phase/recalculation semantics and explicit outcome handling; total/dispose is not success.
- [ ] Commit finished feedback once, remove the region and preserve MultiSpinner's actual all-task completion semantics.
- [ ] Exercise many simultaneous feedback producers, coordinated Text notices and outcome-neutral scope exit with late callbacks.

## Evidence required

Public feedback lifecycle/concurrency tests with fake clocks and shared/standalone output.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
