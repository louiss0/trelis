# Capture the backend regression baseline and deterministic harness
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Capture the current source/public behavior baseline and add reusable deterministic test adapters for selected output, environment, geometry, clocks, input and failures before changing production behavior.

## Acceptance

- [B-BASE](../spec.md#b-base)
- [B-PARITY](../spec.md#b-parity)

- [ ] Run available format/analyze/doc-link/Dart checks and preserve logs, source revision and honest known failures/pending CI status.
- [ ] Inventory existing public/native coverage, historical limitations and 38 component signatures; do not treat old reports as current passes.
- [ ] Provide controllable test seams for stream observations, clock/resize events, scripted input and failing sinks; do not depend on the developer's terminal or font.
- [ ] Keep existing production behavior unchanged and leave unrelated scratch/coverage artifacts alone.

## Evidence required

Baseline report plus deterministic harness tests. Fresh all-platform gate results are required later, not invented here.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
