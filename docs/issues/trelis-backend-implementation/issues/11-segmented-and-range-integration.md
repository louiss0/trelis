# Integrate segmented, range and masked editing with real caret anchors
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 08
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Migrate Slider, RangeSlider, TimeInput, DateInput and MaskedInput to typed editable regions and shared stage rendering.

## Acceptance

- [B-PARITY](../spec.md#b-parity)
- [B-MEASURE](../spec.md#b-measure)
- [B-HELP](../spec.md#b-help)
- [B-RESIZE](../spec.md#b-resize)

- [ ] Retain decimal-string/record results, incomplete segment drafts, native digits, calendar/order and slot/template interpretation rules.
- [ ] Keep field-local caret and semantic focus order through inline/stacked layout, clipping and resize.
- [ ] Preserve adjustment bounds/non-wrapping, explicit Edit/Review/Submit actions and range gap semantics.
- [ ] Supply missing relevant help paths without changing literal entry/capture rules; protect active-format cues and interpretation review.

## Evidence required

Segment/range/mask rich-linear public tests with combining/wide content, partial input and caret restoration.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
