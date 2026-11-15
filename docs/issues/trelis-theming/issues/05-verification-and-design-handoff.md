# Define theming acceptance evidence and the implementation handoff
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 03, 04, 07, 08

## Question

What acceptance matrix and implementation-ready specification will demonstrate the settled API, declarative presentation boundary, per-component help coverage, colour overrides, and rich/linear structural contracts? Define evidence for behavior parity, warning visibility, secret-safe rendering, fallback and output correctness without claiming accessibility qualification from snapshots. Decide the scoped implementation sequence and handoff format, including exact typed factory-signature inventory/forwarding checks against existing constructors, source-compatible presentation parameters and the deliberate PlainTheme/terminal-native default-presentation migration; include OutputProfile invocation/source precedence, explicit synthetic-rich geometry migration, pinned termunicode adapter/display fixtures, shared TerminalSession.run/session: interface and configuration-inheritance checks, one-prompt/multiple-feedback evidence, sequential scripted-input ownership, modal help, overflow/history, isolated/shared failures, outcome-neutral cleanup and idle resize/restoration checks; make backend capability/measurement/compositor implementation and validation precede theme integration, as explicitly requested by bvlou; do not implement it in this design map.

## Answer

Decision recorded from the live exchange: bvlou chose a separate executable backend backlog plus a gated theme handoff, all-component/all-structure verification, and an agent-operated computer-use check instead of a human checkpoint. The final requested correction is explicit: Linux/macOS verification is CI-only; no physical access or human confirmation on those platforms is required. The resulting handoff uses that corrected platform gate.

### Canonical handoff assets

- [Trelis backend-first implementation specification](../../trelis-backend-implementation/spec.md) holds the normative B acceptance matrix, evidence schema, scope/migration requirements and command inventory. All execution evidence starts unverified.
- [Trelis backend implementation order](../../trelis-backend-implementation/dependencies.md) indexes sixteen individually scoped executable tasks. Per-task blockers/acceptance references are authoritative, not a combined build ticket.
- [Trelis gated theme-integration handoff](../../trelis-theme-integration/spec.md) remains blocked on the backend acceptance gate and holds the T verification matrix. It is not an early permission to implement themes.
- [Source API baseline](../api-baseline.md) captures all 38 existing constructor surfaces with field/super-formals expanded to types.
- [Proposed structural-theme factory signatures](../factory-signatures.md) expands the applicable colour/instruction/supplementary parameters for all 38 methods. These are signature notation for compile/forwarding checks, not currently compiled APIs.

The API assets derive from production source revision 80f4752e16a6e3b2451f2b87b9450e535ae3fa30. Implementation must revalidate them against its target revision and preserve generics, defaults, value/result types and feedback lifecycle.

### Evidence boundary

Require actual fresh format/analyze/doc-link/Dart checks and native terminal/PTY evidence on Windows, Ubuntu and macOS CI runners. Linux/macOS native PTY tests execute in CI; they are not physical GUI/font checks. Windows additionally receives the local agent-operated visible-terminal probe. No human appointment or physical Linux/macOS check blocks this work.

Agent computer use exercises actual visible application workflows with generated input and screenshots. NVDA speech observations are included where available and explicitly absent when unavailable. This does not constitute physical-keyboard/human usability evidence or whole-library accessibility qualification. If the visible GUI/tool cannot be used, the GUI gate remains blocked; do not silently substitute unit tests or reintroduce a human checkpoint.

Existing CI configuration, historical component/native reports, syntax-only script compilation and planned fixture counts are not fresh passes. Evidence records revision, environment/SDK/terminal/profile, commands/scenarios, expected/actual results, artifacts and limitations. Required failed or pending checks block the gate.

### Backend-first sequence

The executable tasks cover baseline/harness; profiles/native adapters; pinned Unicode measurement; typed rendering/colour; ordered events/input routing; shared sessions; feedback; four scoped prompt-family migrations; complete help/public compatibility; platform CI/native evidence; agent GUI evidence; and an explicit final evidence audit.

Use a plain reference renderer with real components during backend validation. The fifteen named theme rollout stays blocked until [Accept the backend evidence gate](../../trelis-backend-implementation/issues/16-backend-evidence-gate.md) is explicitly accepted. The gate includes profile/source/legacy compatibility, synthetic geometry migration, termunicode policy fixtures, secret-safe output, complete help/mandatory content, sequential input ownership, concurrency/modal/overflow/resize and all cleanup/failure paths.

### Eventual theme matrix

Require all 38 implemented components across all 15 structures, not only family samples: 570 typed factory pairs and at least 1,125 distinct applicable presentation/task paths (1,020 interactive rich/linear, 90 live-feedback rich/linear, 15 mode-independent Text). Retain deep semantic regressions and add focused stage/help/secret/resize cases. Verify all 45 palette mappings and colour conversion separately; avoid multiplying every task by every palette. Prototype-only components do not count as implemented coverage.

These counts define required future coverage, not tests run during this design session. The exact matrix and migration rules live in the linked theme handoff.

### Completion and next action

All decisions toward the map's destination are resolved, with no remaining fog. Build tasks are deliberately separate from this decision map. The first executable task is [Capture the backend regression baseline and deterministic harness](../../trelis-backend-implementation/issues/01-regression-baseline-and-harness.md).

This session created planning artifacts and checked their consistency; no runtime implementation, dependency change or fresh backend/platform acceptance run occurred. Nothing in closing the map asserts that the backend gate has passed.
