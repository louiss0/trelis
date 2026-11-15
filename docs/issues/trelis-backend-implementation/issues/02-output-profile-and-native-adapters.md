# Unify output profiles, capability detection and native lifecycle adapters
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 01
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Implement the approved OutputProfile types/resolution and one stream-specific capability/native-lifecycle interface shared by prompts and feedback.

## Acceptance

- [B-CAP](../spec.md#b-cap)
- [B-COMPAT](../spec.md#b-compat)
- [B-FAIL](../spec.md#b-fail)

- [ ] Expose the approved typed profile and positive geometry validation with automatic defaults; preserve mode precedence and existing failure shapes.
- [ ] Exercise invocation/source/legacy precedence, selected stdout/stderr, generic sinks, NO_COLOR, TERM=dumb and known redirection restrictions.
- [ ] Document explicit synthetic-rich geometry migration; supportsRich alone supplies no dimensions/Unicode/colour proof.
- [ ] Keep native terminal acquisition/restoration in one owner, make dimensions fallible and inject observations/resize support without competing stdin probes.

## Evidence required

Resolver/adapter tests and native acquisition/restoration regression logs; no named-theme rollout.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
