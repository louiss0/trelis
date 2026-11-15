# 05: Render TextInput from safe typed presentation content

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Display an editable TextInput with independently identified label, body, context and validation, so presentation is no longer a single hard-coded string.

**Blocked by:**
- [03: Support explicit output profiles in scripted TextInput](03-scripted-text-input-profiles.md)

**Status:** resolved

**Acceptance reference:** [B-RENDER](../../trelis-backend-implementation/spec.md#b-render), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Produce immutable display-safe content and a dedicated editable region rather than exposing the mutable editor to layout.
- [x] Render a plain reference view with semantic slots and actual logical-to-physical caret anchoring.
- [x] Insert omitted protected content into the shared safety area while declaration tests still diagnose the omission.
- [x] Encode user/application control and bidi content safely without changing accepted answer data or interpreting text as terminal instructions.
- [x] Verify public validation, labels and relevant instructions remain correct in rich and linear paths.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-05-safe-rendering` in commits `3b6b69e` and `fcbbe3a`. TextInput now renders immutable display-safe semantic content through a dedicated editable region and shared presentation compositor. Omitted relevant protected slots are diagnosed and repaired into a deterministic safety area, while control and bidi content is encoded without changing accepted values. Evidence is recorded in `doc/evidence/trelis-backend/05-safe-typed-text-input.md`. The final focused suites, analyzer and 144-case component matrix passed; one full-suite cron transcript failure passed immediately when rerun in isolation and is recorded as a limitation.
