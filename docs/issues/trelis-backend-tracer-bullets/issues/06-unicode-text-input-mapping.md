# 06: Map Unicode TextInput drafts to display cells and caret positions

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Edit Unicode text in a public prompt using a declared cell-width policy, without confusing grapheme positions with terminal columns.

**Blocked by:**
- [05: Render TextInput from safe typed presentation content](05-safe-typed-text-input.md)

**Status:** resolved

**Acceptance reference:** [B-MEASURE](../../trelis-backend-implementation/spec.md#b-measure), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Pin audited termunicode 0.2.0 with Unicode16/license/lock provenance and use public scalar/property APIs behind the Trelis adapter.
- [x] Retain characters segmentation; do not rely on the known-problematic string-width helper.
- [x] Freeze supported cluster, visible unsupported representation and tab-expansion policies in executed fixtures.
- [x] Cover accents, CJK, ambiguity, flags, modifiers, ZWJ, selectors/keycaps, standalone marks/formats and controls through mapping and public editing cases.
- [x] Verify original-grapheme-to-display/caret mappings and unchanged accepted values, documenting terminal/font limitations.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented in commit `896e586` and refreshed against the integration branch in merge commit `fa30ca2`. Trelis now pins `termunicode: 0.2.0` and maps retained `characters` graphemes through an internal `TextDisplayMap` using public scalar/property APIs. Executed fixtures cover decomposed accents, CJK, ambiguous widths, flags, modifiers, ZWJ emoji, selectors/keycaps, standalone marks and formats, controls/bidi, visible unsupported representations, caret mappings and unchanged accepted values. Evidence, Unicode 16/license/archive-lock provenance and terminal/font limitations are recorded in `assets/evidence/trelis-backend/06-unicode-text-input-mapping.md`.
