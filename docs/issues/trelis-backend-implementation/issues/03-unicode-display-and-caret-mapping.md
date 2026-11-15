# Implement pinned Unicode display measurement and caret mapping
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 01
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Pin the audited termunicode scalar/property dependency behind the internal Trelis adapter, retain characters segmentation and implement explicit supported-cluster/display mapping policy.

## Acceptance

- [B-MEASURE](../spec.md#b-measure)
- [B-SECRET](../spec.md#b-secret)

- [ ] Use exact 0.2.0 with license/Unicode16/archive-lock evidence; avoid internal imports and known-problematic string helpers.
- [ ] Freeze supported emoji/variation/keycap, unsupported escape and tab-expansion policy in fixtures; distinguish raw cluster width from encoded display width.
- [ ] Test accented/decomposed/CJK/ambiguous/combining-only/flags/modifiers/ZWJ/VS15/VS16 and control/bidi/tab/newline cases.
- [ ] Verify original grapheme-to-display/caret mappings and hidden/masked alternatives without secret length leakage; state terminal/font limitations.

## Evidence required

Executed width/mapping fixtures tied to the pinned policy/version, not a universal terminal conformance claim.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
