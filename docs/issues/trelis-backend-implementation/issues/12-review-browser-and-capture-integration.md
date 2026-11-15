# Integrate review workflows, filesystem browsing, cron and key capture
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 08, 09
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Migrate PathInput, FilePicker, DirectoryPicker, CronInput, Keypress and KeyChordInput to shared workflow/body/event interfaces.

## Acceptance

- [B-PARITY](../spec.md#b-parity)
- [B-HELP](../spec.md#b-help)
- [B-SECRET](../spec.md#b-secret)

- [ ] Retain literal path/escaping, browser operations/context, link approval and explicit no-sandbox/later-operation caveats.
- [ ] Preserve cron profile/preview configuration and edit/preview/submit review rather than invent syntax support or scheduler guarantees.
- [ ] Preserve gesture provenance, observation requirements and reserved interruption/capture semantics; help cannot steal a captured gesture.
- [ ] Exercise staged input, action prompts and review with concurrent feedback, help, EOF and typed failures.

## Evidence required

Public review/browser/cron/capture tests with truthful warnings and mode/stage-specific help.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
