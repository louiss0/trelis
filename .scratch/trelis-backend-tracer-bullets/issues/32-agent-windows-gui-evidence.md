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

Agent-operated Windows terminal evidence at `b94efda3779fe24ae41164ddd53015be7621d814` is recorded in [the GUI report](../../../doc/evidence/trelis-backend/32-agent-windows-gui.md). Every named B-GUI checkpoint is captured and inspected at that one code revision, so nothing is carried forward from an older harness:

- concurrent `Text`/`Spinner`/`Progress` writes with caret movement and insertion (`alpha` → `alpXha`), modal help with real paragraph breaks and a cleared draft row, dismissal, and private entry with no echo (screenshots 11–17, outcome `GUI-PROBE:accepted:alpXha;secret:accepted`);
- ASCII/no-colour fallback under `--ascii`: uncoloured, ASCII-only, wrapped at 40 columns, with its own help, dismissal and outcome `GUI-PROBE:accepted:alpha` (18, 19, 21);
- narrow/idle resize at 1000x620 → 620x420 through an explicit Win32 `MoveWindow`, with modal help and dismissal at narrow width (22–26);
- repeated prompts in one session (`27`, `GUI-PROBE:accepted:alpha,alpha`);
- a genuine required-value rejection followed by recovery (`28`, `29`: `Required: enter a non-empty value and submit again.` then `GUI-PROBE:accepted:beta`);
- cancellation and interruption cleanup (`30`, `31`: both named regions completed, `GUI-PROBE:cancel` / `GUI-PROBE:interrupt`).

Environment and method are recorded with the artifacts: Orca `1.4.259` / `orca-computer-use-windows` `1.0.0` supplied observation and screenshots only. The provider reports `Input: background=false` and refused key input with `window_not_focused`; `--restore-window` takes over the human's keyboard and was not used, so synthetic keys were injected with the repository's existing Win32 `AttachConsole`/`WriteConsoleInput` pattern. Resize used Win32 `MoveWindow` because the provider exposes no resize action. NVDA was absent (`nvda-command=; nvda-process-count=0`), so no physical-keyboard, human-usability or accessibility qualification is claimed.

One captured limitation is stated rather than glossed: the visible adapter declares a fixed geometry at launch and has no native resize notification, so an idle resize does not reflow the prompt — the narrow frames show draft/caret preservation plus terminal soft wrap, not adaptive relayout. Live resize reflow remains unclaimed.

The superseded `7676a5f` captures (`06`–`10`) are deleted, including the misleading "error-recovery" frame that only showed an optional empty submission; their checkpoints are replaced by the fresh captures above.
