# Investigate editable defaults in linear interaction

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-editable-defaults
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Question

Which terminal/editor mechanisms can provide actual editable initial values in Trelis's linear mode across Windows, macOS and Linux, while keeping output reviewable and respecting no implicit input-source/controlling-terminal takeover? The human rejected showing a pending default accepted by /submit; an incapable chosen mode must report unavailable rather than silently alter that interaction. Investigate Dart TUI, Dart/native terminal APIs and relevant primary editor documentation, distinguish native cooked-line capabilities from application-managed editors, assess screen-reader/redirection limitations, and identify capability checks or minimal experiments needed. Do not assume a custom redraw editor is automatically equivalent to linear interaction or verified accessible.

## Answer

Documentation investigation is complete. Dart readLineSync has no initial-buffer API, and standard POSIX canonical input provides no portable arbitrary-prefill operation. Printing a default does not install it into editable input. Windows ReadConsoleW with nInitialChars is a candidate; application-managed editors such as Readline and Dart editing models are other candidates. Their suitability for Trelis's selected streams, linear transcript, grapheme behavior, lifecycle and assistive technology remains unverified. Native input injection is not a portable default solution.

No backend was adopted or changed. Package API/search evidence remains version-sensitive, and evidence concerning artisanal must not be conflated with dart_tui or the archived patched 3.0.0 trial. Exact archive/source review and controlled prototypes are needed before capability claims. No platform or screen-reader tests were performed.

The human's actual-editable-default requirement remains intact; report interaction unavailable when the selected mode/backend cannot satisfy it. Research also exposed a precise editing decision: how initial values matching commands or leading-backslash quoting remain literal on Enter. Resolve that with the human in the active editing ticket rather than silently rewriting values or bypassing command recognition. The existing verification-matrix ticket must include editor-prefill/EOF/stream/provenance probes; exact backend mechanisms are not selected by this report.

## Research context

- Spawned by [Specify text and structured-input interactions](05-editing-prompt-contracts.md); other independent discussion in that ticket can proceed.
- Worker: cb5d69cd-4c6b-40e
- Worktree: C:/Users/bvlou/projects/trelis-research-editable-defaults (created from bd5a19f)
- Research branch: research/trelis-editable-defaults
- Completed report: [Editable initial defaults in Trelis terminal prompts](../../../doc/research/trelis-editable-defaults.md)
- Exact report commit: 4b54ff62dd884d055456ff5b7c2409a2ade4a6a3 on research/trelis-editable-defaults; parent saved and committed only this report, and the worktree is clean.
- Actual platform and assistive-technology validation remains separate.
