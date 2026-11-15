# Build typed presentation, protected composition and colour rendering
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 02, 03
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Implement the internal typed content/layout vocabulary and shared renderer with a plain reference declaration for backend testing.

## Acceptance

- [B-RENDER](../spec.md#b-render)
- [B-SECRET](../spec.md#b-secret)

- [ ] Provide immutable safe body variants, semantic slots/styles and dedicated editable regions; no controllers, validators or behavior callbacks enter layout.
- [ ] Compose rows/columns/frames/rails and body templates; measure prefixes/borders, wrap read-only content and keep editable caret in its viewport.
- [ ] Implement protected-slot insertion plus declaration coverage diagnostics; essential roles are not instruction copy.
- [ ] Add backend-facing complete colour/value types, conversion/tie-breaking, component-local backgrounds and state restoration; do not implement all named presets/classes.
- [ ] Exercise secret-safe projections and encoded controls, actual caret anchors and real redirected no-ANSI output.

## Evidence required

Layout/renderer/colour fixtures using explicit synthetic profiles and plain reference content.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
