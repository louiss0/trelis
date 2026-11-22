# 04: Resolve native TextInput capabilities and restore terminal state

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Make a real native TextInput select safe output behavior and leave the terminal usable after every supported exit.

**Blocked by:**
- [03: Support explicit output profiles in scripted TextInput](03-scripted-text-input-profiles.md)

**Status:** resolved

**Acceptance reference:** [B-CAP](../../trelis-backend-implementation/spec.md#b-cap), [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail), [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat).

- [x] Observe the selected output handle, including stderr/stdout independence, dumb output, real redirection and fallible dimensions.
- [x] Resolve automatic versus explicit-rich behavior without treating cursor support as colour, font or alternate-screen proof.
- [x] Exercise acceptance, cancellation, interruption, EOF, repeated sessions and acquisition/input/output errors through public/native scenarios.
- [x] Restore received native state on supported paths and preserve the original error context if restoration also fails.
- [x] Retain profile restrictions and lazy explicit input policy; no unsolicited terminal replies consume answer input.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-04-native-capabilities` in commit `02a1aa9`. Native and public TextInput scenarios now resolve output conservatively, restore supported terminal state on all exercised exits, and preserve both operation and restoration failures through `TerminalRestorationException`. Evidence is recorded in `assets/evidence/trelis-backend/ticket-04-native-capabilities.md`. Linux/macOS native CI, GUI/NVDA evidence, NO_COLOR-specific native coverage and injected native dimension-query failures remain assigned to later gate work.
