# Implement ordered presentation events and shared input routing
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 02
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Separate current snapshots from meaningful events and establish a session-owned input router/source lifetime for sequential prompts.

## Acceptance

- [B-EVENT](../spec.md#b-event)
- [B-PARITY](../spec.md#b-parity)

- [ ] Assign occurrence identities and serialize source/region events; repeated help/errors remain distinct while repaint/resize/no-op keys do not duplicate history.
- [ ] Retain literal-command quoting, identified paste provenance, grapheme input semantics and typed async generation boundaries.
- [ ] Consume a scripted stream once across sequential leases without close/resubscribe loss or key broadcasting.
- [ ] Keep input leases and output delivery independent; preserve existing callback/cadence contracts rather than using onChanged as a text-change oracle.

## Evidence required

Event-order/idempotence and sequential-input fixtures, including EOF/cancel/interrupt and buffered source data.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
