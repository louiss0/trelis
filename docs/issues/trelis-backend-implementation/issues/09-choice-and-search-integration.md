# Integrate choices, search, hierarchy and ordering with typed regions
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 08
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Migrate Select, Radio, MultiSelect, TreeSelect, SortableSelect, Autocomplete, SearchSelect, CommandPalette and TimezoneSelect without theme-specific input loops.

## Acceptance

- [B-PARITY](../spec.md#b-parity)
- [B-HELP](../spec.md#b-help)
- [B-EVENT](../spec.md#b-event)

- [ ] Preserve generic values, stable references/pages, separate focus/checked/default/unavailable state, tree selectability and locked anchors.
- [ ] Retain query/results stages, async generation/closure rejection, loading/error/empty distinctions and actual retry rules.
- [ ] Keep SearchSelect source identities distinct from response-local Autocomplete candidates; acceptance versus text submission remains explicit.
- [ ] Exercise filtering/review/clear-visible/movement and stage-aware help under background updates, clipping and source EOF.

## Evidence required

Public family matrix, stale response/focus fixtures and typed safe content checks.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
