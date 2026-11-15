# 32: Exercise the backend through agent-operated Windows computer use

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Observe the implemented backend in a visible Windows terminal using an agent rather than a human checkpoint.

**Blocked by:**
- [30: Complete compatibility checks and retire migrated legacy paths](30-compatibility-and-contract.md)

**Status:** resolved

**Acceptance reference:** [B-GUI](../../trelis-backend-implementation/spec.md#b-gui), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret), [B-MODAL](../../trelis-backend-implementation/spec.md#b-modal), [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize).

- [x] Follow the installed computer-use skill and version-matched guide; use a dedicated visible terminal and synthetic inputs.
- [x] Exercise editing/caret, multiple feedback/Text, modal help, narrow/idle resize, ASCII/no-colour, private entry and repeated/error/cancel/interruption cleanup.
- [x] Capture screenshots and expected/observed checkpoints with revision, tool/terminal versions and input-generation method.
- [x] Inspect NVDA speech when available and record its source/configuration or absence; do not claim physical-keyboard/human usability or accessibility qualification.
- [x] GUI/tool access was available; no human checkpoint was used.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Agent-operated Windows terminal evidence at `a598c8e` is recorded in [the GUI report](../../../doc/evidence/trelis-backend/32-agent-windows-gui.md). It covers synthetic caret movement and editing under concurrent `Text`/`Spinner`/`Progress` writes, transcript-fallback modal help with correct line breaks and draft-row clearing, dismissal, and private entry. The accepted draft was `alpXha` and the harness printed `GUI-PROBE:accepted:alpXha;secret:accepted`. NVDA was absent; no physical-keyboard, human-usability, or accessibility qualification is claimed.

The earlier blocked verdict at `7676a5f` is superseded: help no longer renders paragraph breaks as `\u{000A}`, and a session-owned help block no longer writes onto the live draft row. Narrow/idle resize, ASCII/no-colour, and the repeated/error/cancel/interruption cleanups were not re-run in this visible window; they stay anchored to the earlier observation and to scripted tests at this revision.
