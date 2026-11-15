# 03: Support explicit output profiles in scripted TextInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Run an actual TextInput using declared output capabilities and geometry, with predictable rich/linear behavior on scripted sinks.

**Blocked by:**
- [02: Expand the shared terminal I/O seam without changing behavior](02-expand-terminal-io-seam.md)

**Status:** resolved

**Acceptance reference:** [B-CAP](../../trelis-backend-implementation/spec.md#b-cap), [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat).

- [x] Expose the approved immutable OutputProfile vocabulary and field-by-field resolution through TextInput invocation and scripted-source configuration.
- [x] Require positive declared geometry for synthetic rich output; do not invent a virtual screen from supportsRich.
- [x] Exercise invocation/source/legacy precedence with public calls, automatic fallback and explicit-rich Unavailable outcomes.
- [x] Keep supplied-answer validation independent of terminal acquisition and preserve literal commands, input results and constructor defaults.
- [x] Treat unproven colour/glyph/style facts conservatively; profile requests do not force unsupported output.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-03-output-profiles`. The public profile vocabulary and resolver are exported through `package:prompty/prompty.dart`; `TextInput.prompt`, `ScriptedInput`, and optional `TerminalIoOutputProfile` apply them at the approved public seams. `doc/evidence/trelis-backend/ticket-03-output-profiles.md` records the behavior, commands, environment, results, and remaining backend-gate limitations.

The focused public profile/TextInput/terminal-I/O checks, 144-case component acceptance matrix, formatter, analyzer, documentation-link check, and full 654-test suite passed before resolution. Rich scripted fixtures now declare positive 100x30 geometry; automatic and explicit-rich behavior without it is asserted separately.
