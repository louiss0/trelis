# Integrate core editors, secrets, booleans and tags with the shared backend
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 06, 07
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Migrate TextInput, Password, Confirm, Checkbox, Toggle, Multiline and TagInput onto typed projections/shared input and rendering using the plain reference presentation.

## Acceptance

- [B-PARITY](../spec.md#b-parity)
- [B-SECRET](../spec.md#b-secret)
- [B-HELP](../spec.md#b-help)
- [B-SESSION](../spec.md#b-session)

- [ ] Preserve constructor/default/validation/outcome and editing semantics, typed source policy and literal/paste distinctions.
- [ ] Add supported invocation profile/session configuration, sequential leases and second-prompt rejection before input consumption.
- [ ] Keep hidden/masked drafts safe, generic secret validation and real Enter/action-stage distinctions.
- [ ] Verify editable defaults/caret, multiline finish versus newline, tag add versus finish, boolean defaults and help restoration while feedback updates.

## Evidence required

Public rich/linear and secret-safe component regressions, plus one actual prompt with multiple feedback regions.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
