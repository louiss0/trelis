# Trelis declarative theming design
Labels: wayfinder:map
Status: resolved

## Destination

An implementation-ready design for adapting Trelis's existing components to the already-decided structural themes, with separate colour themes, deliberate rich and linear presentations, and compact, component-aware help. This effort produces decisions and a handoff specification, not implementation.

## Notes

- This completed map is design-only. Do not reopen theme selection or redesign the existing visual directions.
- The consolidated [ready-for-agent specification](spec.md) synthesizes the agreed problem, user stories, implementation and testing decisions without changing this map's resolved state.
- Execution artifacts: [Backend-first implementation specification](../trelis-backend-implementation/spec.md), [backend dependency index](../trelis-backend-implementation/dependencies.md) and [gated theme handoff](../trelis-theme-integration/spec.md).
- Platform evidence is CI-based on Linux/macOS, without physical access; Windows also has a local agent-operated visible-terminal probe. No human checkpoint is required.
- Multiple live regions on one output are required. The shared session/compositor contract is resolved in [Specify shared multi-region output composition](issues/08-multi-region-output-composition.md); independent cursor writers are not a supported substitute.
- Execution order approved by bvlou: design the backend first, then implement and validate its capability/measurement/rendering foundations before theme integration. The handoff must make theme integration depend on that backend work; do not start coding until the backend interface and evidence requirements are settled.
- Consult grilling and domain-modeling for decision sessions; consult Dart and codebase-design when designing API/type or rendering boundaries.
- Local Markdown tracker conventions apply. Child issues live in issues/. Open, unblocked, unclaimed children form the frontier, ordered by filename. Claim before working. Resolve at most one non-research ticket per session.
- Structure and colour are separate. Static structural-theme factories and per-component colour configuration are resolved in [Specify structural-theme factories and colour configuration](issues/03-static-theme-api-and-colours.md); use that ticket for exact names, parameters and defaults.
- Full existing structural flexibility is required, not merely colours on fixed component layouts.
- Both rich and linear interaction receive deliberate structural presentations; linear interaction remains sequential and reviewable.
- Themes control instruction presentation per component; applications can override it.
- Generally show compact, component-appropriate help text leading to fuller help. Prompt labels are not the instructions being hidden.
- Relevant safety warnings remain visible; structure may control placement and styling, not bury them in help.
- Existing component behavior is shared rather than reimplemented per structure.
- Existing instructions must inform the design. See [Current component help inventory](help-inventory.md).
- Design inputs: example/prototype-themes/generate.py (palette specifications, vocabulary, prompt layouts and specimens); example/prototype-themes/structures.html. Atlas editorial sheet headings are not runtime component instructions.
- Earlier context: ../trelis-accessible-prompts/spec.md. Existing theme selection is an input, not a new question.
- Approved factory and palette identifiers/defaults now live in [Specify structural-theme factories and colour configuration](issues/03-static-theme-api-and-colours.md); consult its resolution rather than the early illustrative examples.

## Decisions so far

- [Define compact guidance and full help for every component](issues/01-component-help-contract.md): Stage-aware primary-action hints lead to complete component help; preserve essential context and warnings, use safe help-access exceptions, and allow presentation overrides plus supplementary help.
- [Define the declarative component presentation boundary](issues/02-declarative-presentation-boundary.md): Internal composable layouts consume typed, display-safe state; shared behavior owns actions and results, while the terminal renderer owns physical output and colour resolution.
- [Specify structural-theme factories and colour configuration](issues/03-static-theme-api-and-colours.md): Fifteen named static factory classes share complete ten-role colour palettes and instruction options; direct constructors use PlainTheme and all structures default to terminal-native colours.

- [Specify the internal typed presentation and layout vocabulary](issues/06-internal-presentation-vocabulary.md): Typed bodies and dedicated editable regions compose into layouts; ordered linear events avoid repaint duplicates, and a shared safety area inserts omitted protected content.

- [Specify rich and linear presentations for the existing structures](issues/04-rich-and-linear-structure-contracts.md): Preserve the fifteen grammars with compact linear events, bounded stable sizing, progressive chrome simplification, local Ledger numbering and conservative colour/ASCII fallback.

- [Specify shared output capabilities and display measurement](issues/07-output-capabilities-and-measurement.md): Shared OutputProfile resolution, explicit synthetic geometry, idle resize handling and a pinned termunicode-backed adapter form the backend foundation; multi-region composition is a separate required decision.

- [Specify shared multi-region output composition](issues/08-multi-region-output-composition.md): Explicit scoped sessions coordinate one prompt plus multiple feedback regions, vertical stacking, modal help, ordered history and outcome-neutral cleanup.

- [Define theming acceptance evidence and the implementation handoff](issues/05-verification-and-design-handoff.md): A sixteen-task backend backlog and explicit evidence gate precede theme integration; Linux/macOS use CI-only native checks, Windows adds agent GUI evidence, and all component/structure pairs require coverage.

## Not yet specified

None. All design decisions are resolved. Implementation proceeds through the separate backend backlog, with theme integration blocked until its evidence gate passes.

## Out of scope

- Choosing new themes or revisiting the existing theme selection.
- Several simultaneously interactive prompts, cross-prompt focus switching and application-declared grid/region positioning; the scoped prompting compositor suffices, as resolved in [Specify shared multi-region output composition](issues/08-multi-region-output-composition.md).
- Public custom-structure authoring or a general-purpose public layout framework; this effort keeps declarations internal, as resolved in [Define the declarative component presentation boundary](issues/02-declarative-presentation-boundary.md).
- Implementing or refactoring components during this planning effort.
- Package-wide rename/release migration: Trelis is the project name, but package/import changes were not requested.
- Claiming whole-library accessibility qualification from a theming design.
- Cross-prompt Ledger flow numbering or caller-supplied step configuration; this effort uses local stage numbering, as resolved in [Specify rich and linear presentations for the existing structures](issues/04-rich-and-linear-structure-contracts.md).
