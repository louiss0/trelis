# 11: Provide compact and full TextInput help safely

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use compact guidance and open accurate full help without losing an editable answer.

**Blocked by:**
- [07: Keep the TextInput caret usable in narrow viewports](07-narrow-text-input-viewport.md)

**Status:** resolved

**Acceptance reference:** [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-RENDER](../../trelis-backend-implementation/spec.md#b-render), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Implement theme-default/compact/expanded/hidden optional guidance and additive supplementary help for TextInput.
- [x] Keep label, context, validation and a usable help route protected regardless of instruction visibility.
- [x] Describe the actual current controls and preserve draft/focus/caret across open/dismissal.
- [x] Use reviewable transcript help when temporary screens are unsupported, without changing answer/command semantics.
- [x] Verify escape/interruption/EOF/error and validation paths through public interactions.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented in commit `b42297c` and refreshed against resize and colour integration in `1ec3114`. TextInput now exposes `InstructionDisplay`, configurable compact/expanded/hidden guidance and additive supplementary help while protecting label, context, validation and help access. Rich and linear help describe current controls, preserve draft/caret, provide transcript fallback, and cover validation plus cancellation/interruption/EOF/error outcomes through public tests. Evidence is recorded in `assets/evidence/trelis-backend/11-text-input-help.md`.
