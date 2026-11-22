# 09: Apply capability-aware colours to TextInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Apply a complete colour theme to an actual TextInput while keeping native defaults, disabled-colour settings and redirected output safe.

**Blocked by:**
- [05: Render TextInput from safe typed presentation content](05-safe-typed-text-input.md)
- [04: Resolve native TextInput capabilities and restore terminal state](04-native-text-input-capabilities.md)

**Status:** resolved

**Acceptance reference:** [B-RENDER](../../trelis-backend-implementation/spec.md#b-render), [B-CAP](../../trelis-backend-implementation/spec.md#b-cap).

- [x] Implement immutable ten-role ColorTheme and typed TerminalColor values with validated bounds, complete construction and copyWith.
- [x] Exercise foreground/context/hint/error styling through public prompt output and preserve non-colour meaning.
- [x] Implement deterministic supported RGB/indexed/default resolution and documented downgrade/tie-breaking without claiming customized ANSI slots were measured.
- [x] Honor nonempty NO_COLOR and known real redirection even for explicit palette/profile requests; preserve permitted monochrome behavior independently.
- [x] Restrict backgrounds to owned cells and restore styles without affecting unrelated output or forcing a dark/light terminal.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented in commit `7793315` and refreshed against resize integration in `430b32a`. Public immutable `TerminalColor`, ten-role `ColorTheme`, and `ColorThemes.terminalDefault` now drive semantic TextInput styling with deterministic RGB/indexed/ANSI16 downgrade rules. Native defaults, nonempty `NO_COLOR`, real redirection and monochrome output remain hard restrictions; backgrounds are limited to owned cells and styles are restored. Evidence is recorded in `assets/evidence/trelis-backend/09-text-input-colour-rendering.md`.
