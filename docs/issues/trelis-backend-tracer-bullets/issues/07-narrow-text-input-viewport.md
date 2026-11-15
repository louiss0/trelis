# 07: Keep the TextInput caret usable in narrow viewports

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Keep a real editable answer usable at the beginning, middle and end of a narrow prompt while surrounding text remains readable.

**Blocked by:**
- [06: Map Unicode TextInput drafts to display cells and caret positions](06-unicode-text-input-mapping.md)

**Status:** resolved

**Acceptance reference:** [B-RENDER](../../trelis-backend-implementation/spec.md#b-render), [B-MEASURE](../../trelis-backend-implementation/spec.md#b-measure), [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize).

- [x] Scroll the single-line editable region around its actual caret with truthful overflow indicators.
- [x] Account for prefixes, padding and safe display substitutions without splitting graphemes or changing answer data.
- [x] Wrap read-only labels, context and validation and retain protected content rather than silently truncating it.
- [x] Keep stage geometry stable during typing and respect actual available width and the documented total-width cap.
- [x] Verify edited/default Unicode answers and caret moves through public interaction tests, not only measurement helpers.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented in commits `eb19e88` and `e0c3382`, then refreshed against integration in `a42d766`. Rich TextInput now uses declared geometry for a caret-centred single-line viewport, reserves structural cells and truthful `<`/`>` indicators, adds only complete display graphemes, wraps protected read-only content, preserves safe substitutions and accepted values, and applies the documented 120-column total-width cap. Public tests exercise Unicode default editing and caret movement under narrow geometry. Evidence is recorded in `doc/evidence/trelis-backend/07-narrow-text-input-viewport.md`.
