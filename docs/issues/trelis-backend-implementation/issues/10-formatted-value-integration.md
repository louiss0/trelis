# Integrate formatted text and value wrappers with safe display context
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 08
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Migrate NumberInput, PortInput, IPAddressInput, URLInput, EmailInput, ColorInput and DurationInput onto the backend while retaining parsing/value contracts.

## Acceptance

- [B-PARITY](../spec.md#b-parity)
- [B-SECRET](../spec.md#b-secret)
- [B-HELP](../spec.md#b-help)

- [ ] Preserve numeric conventions/nullable values/precision, network formats, SMTPUTF8, colour value and duration mode semantics.
- [ ] Separate minimal active-format cues, syntax help, interpretation/preview and relevant limitations/warnings.
- [ ] Preserve hidden URL draft and approved accepted interpretation behavior; no blanket URL-redaction or network-guarantee claim.
- [ ] Verify profile/session forwarding and safe text/diagnostics without converting values to another numeric representation.

## Evidence required

Public typed-value, cue/help/warning, hidden-draft and preview regressions.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
