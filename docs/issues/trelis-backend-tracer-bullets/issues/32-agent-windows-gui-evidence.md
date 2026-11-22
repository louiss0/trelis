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

Agent-operated Windows terminal evidence at `b94efda3779fe24ae41164ddd53015be7621d814`
is recorded in [the GUI report](../../../../assets/evidence/trelis-backend/32-agent-windows-gui.md),
which is the canonical description of every frame: the synthetic action, the
checkpoint it satisfies and the expected-versus-observed note. Every named
B-GUI checkpoint is captured at that one code revision, so nothing is carried
forward from an older harness.

Environment and method are recorded with the artifacts: Orca `1.4.259` /
`orca-computer-use-windows` `1.0.0` supplied observation and screenshots only;
synthetic keys were injected with the repository's existing Win32
`AttachConsole`/`WriteConsoleInput` pattern because the provider refused
background key input (`window_not_focused`), and resize used Win32 `MoveWindow`
because the provider exposes no resize action. NVDA was absent
(`nvda-command=; nvda-process-count=0`), so no physical-keyboard, human-usability
or accessibility qualification is claimed.

One captured limitation is stated rather than glossed: at this revision the
visible adapter declared a fixed geometry at launch and had no native resize
notification, so an idle resize did not reflow the prompt — the narrow frames
show draft/caret preservation plus terminal soft wrap. The post-review fixes add
a reachable native observation path and prove idle reflow from a real Windows
console resize and a POSIX PTY resize
([post-review record](../../../../assets/evidence/trelis-backend/post-review-fixes.md));
these frames were not re-captured and are not re-described as adaptive relayout.

The superseded `7676a5f` captures (`06`–`10`) are deleted, including the
misleading "error-recovery" frame that only showed an optional empty submission;
their checkpoints are replaced by the fresh captures in the report.