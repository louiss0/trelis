# Trelis gated theme-integration handoff
Status: blocked
Blocked by: [Accept the backend evidence gate](../trelis-backend-implementation/issues/16-backend-evidence-gate.md)
Acceptance: not verified

## Start condition

Do not begin the fifteen-theme rollout until the [backend specification](../trelis-backend-implementation/spec.md) gate is explicitly accepted with current evidence. Backend integration with a plain reference presentation is allowed in that backlog solely to validate actual components; it does not open this work early.

This is the next-phase specification, not a set of prematurely takeable build tickets. Slice implementation tasks after the backend gate while preserving these already-settled requirements. That slicing does not reopen theme selection or architecture decisions.

## Authoritative design and interface

- [Theming decision map](../trelis-theming/map.md) links the canonical decisions.
- [Factory/colour configuration](../trelis-theming/issues/03-static-theme-api-and-colours.md) defines the fifteen public classes, shared typed factories, complete palettes/defaults and instruction interface.
- [Rich/linear structure contracts](../trelis-theming/issues/04-rich-and-linear-structure-contracts.md) defines the structure matrix and responsive/capability policy.
- [Component help contract](../trelis-theming/issues/01-component-help-contract.md) and [current inventory](../trelis-theming/help-inventory.md) define guidance coverage and source migration needs.
- [Typed presentation vocabulary](../trelis-theming/issues/06-internal-presentation-vocabulary.md) and the resolved backend/session decisions remain constraints, not implementations to duplicate.
- [Source signature baseline](../trelis-theming/api-baseline.md) and [expanded proposed factory signatures](../trelis-theming/factory-signatures.md) provide the exact typed forwarding surface. Recheck against the implemented source revision; these are signature notation, not compiled code.

## Implementation sequence after the gate

1. Expand the full typed factory surface for the fifteen approved structural classes and independent named/custom colour objects. Keep shared behavior and configuration immutable; do not add one behavior class per structure/palette combination.
2. Implement all fifteen rich declarations and deliberate linear event counterparts using the backend's typed primitives. Validate grammar/slot coverage and protected-content repair, not merely borders around an opaque fixed body.
3. Apply component-aware instruction defaults/overrides and full help through those declarations; retain warnings, cues, state, validation and review actions. The backend's completed help/semantic contract is reused, not rewritten as per-theme input loops.
4. Validate the component/structure matrix, palette mapping/conversion and migration behavior; inspect representative normal/narrow visible output through agent computer use. No human checkpoint or physical Linux/macOS verification is introduced.
5. Update public documentation/examples and record actual evidence/limitations. Packaging/import renaming and accessibility qualification remain outside this effort.

## Theme acceptance matrix

### T-API

All fifteen approved structural classes expose all 38 methods in the signature inventory, preserving concrete return types, generics, positional/named/required arguments and defaults. This is 570 class-method pairs. Compile representative/all generated call fixtures, test forwarding with distinguishable non-default constructor/presentation arguments and verify no terminal I/O/validation/callbacks occur at construction. Helpers/generators must not replace typed public methods with dynamic argument bags.

Retain direct constructors using PlainTheme's presentation with terminal-native default colours, while preserving invocation configuration/result/lifecycle semantics. Theme factories configure objects; they do not invoke prompt/present/start. Feedback classes do not acquire irrelevant instruction parameters. Session/profile configuration remains on invocation.

### T-COMPONENT-STRUCTURE

Every implemented component must be covered across every structure, not just a family sample. Minimum distinct path counts:

- 34 interactive components x 15 structures x 2 modes = 1,020 public render/task smoke paths.
- Progress, Spinner and MultiSpinner x 15 structures x 2 modes = 90 feedback lifecycle/render paths.
- Text x 15 structures = 15 mode-independent presentation paths; do not count two labels as evidence of two Text renderers.
- Total minimum distinct applicable presentation/task paths: 1,125, in addition to the 570 factory surface pairs.

Those are required planned coverage counts, not executed results. Exclude prototype-only StepperForm and other unimplemented names; do not claim all atlas names are public components. Smoke fixtures must exercise visible presentation/task output, not only SuppliedAnswer validation that bypasses rendering.

Retain the complete deep semantic regression suite. Add stage/help/failure/secret/resize cases per family and targeted cross-structure edge cases beyond the minimum matrix. The shared backend handles input; structure tests still need to prove no omitted/misplaced typed content and no altered acceptance/focus/reference semantics.

### T-PALETTE

Verify all 45 named preset mappings against source atlas RGB values, including ten-role completeness, page-colour exclusion, selection mapping and the documented warning fallback. Verify custom palettes/copyWith immutability, whole-palette replacement, terminal-native defaults, lack of global mutation and no forced dark/light surface.

Test conversion/NO_COLOR/redirected/glyph/style policy through backend fixtures independently of every component interaction. Do not require the redundant full component x structure x palette Cartesian product, but include integration fixtures proving that an alternate palette works across structurally different layouts and that per-component overrides do not leak to neighbors.

### T-STRUCTURE

For each grammar compare semantic frame/declaration snapshots and representative visible output against the approved anatomy, not exact prototype fixed widths or pixel fonts. Verify hints inside/outside their prescribed chrome, choice breathing space, prompt-local Ledger stage numbering, title versus answer/command case handling, component-local backgrounds and distinct focus/checked/default/unavailable state. Preserve 80-column total cap, stable editing geometry, grapheme-safe wrapping/caret viewports, resize and structure-specific ASCII counterpart.

Exercise rich and linear separately: full stage/help/review framing and compact matching linear events; no repaint duplicates, ANSI in real redirected logs or fabricated completion. Verify local profile/palette changes cannot force unsupported rich output.

### T-INSTRUCTIONS

Run theme-default/compact/expanded/hidden policies with application supplementary help, active-format cues, validation/review and relevant warnings. Hidden optional guidance keeps a discoverable help route and protected content. Test stage-specific primary actions (including Enter meanings), complete component-specific help and safe secret/capture exceptions. Deliberately omit required slots in fixtures and assert shared insertion without silently validating the declaration as correct.

### T-EVIDENCE

Use the backend evidence schema with current revision and separate automated, CI-native and agent-GUI observations. Linux/macOS checks are CI-only; no physical access is required. Agent GUI probes use visible Windows terminal output; NVDA speech observations are included when available with limitations. No human checkpoint, actual-physical-keyboard claim or whole-library accessibility qualification follows from injected GUI input, native tests or snapshots.

Theme acceptance cannot be declared merely because backend acceptance passed: the new factory/layout matrix needs its own evidence. Any backend regression discovered during theme work reopens the affected backend gate evidence; do not bypass it by relaxing theme snapshots.

## Migration and limits

Document the project's name as Trelis while retaining package/import names unless a separate rename effort is authorized. Explain direct-constructor default presentation changes, compact help, warning visibility, palette/default changes, profile/session options and explicit geometry for scripted rich output. Preserve all accepted value types, cancellation/interruption/EOF/unavailable distinctions and feedback outcomes.

Whole-library accessibility and universal terminal/font width correctness remain unqualified. Existing observations are revision/environment-specific. This handoff does not require users to physically confirm macOS or Linux; actual CI runner results and artifacts satisfy that platform portion.
