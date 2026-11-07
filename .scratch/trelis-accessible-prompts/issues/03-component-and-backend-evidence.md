# Component interaction precedents and Dart TUI feasibility

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-component-feasibility
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Research context

- Worker: 4fa35609-3f44-442
- Research branch: research/trelis-component-feasibility
- Worktree: C:/Users/bvlou/projects/trelis-research-component-feasibility
- Completed report: [Component interaction precedents and Dart TUI feasibility](../../../doc/research/trelis-component-feasibility.md).
- Exact report commit: 8b389e4c13eac1ef1776f5082c0b150bd27f53de on research/trelis-component-feasibility. Parent saved the full worker report and committed only that file; research worktree is clean.

## Answer

Research is complete with a traceability row for each of the 39 in-scope specimens, actual terminal-library precedents, backend capability evidence and explicit limitations. The atlas proposes shortcuts such as Alt+Enter, Ctrl+Enter and modified arrows whose availability cannot be assumed in legacy terminal input. Existing shared and component-family decision tickets must choose discoverable alternatives, distinguish focus/candidate/selection/submission, and define validation and output policy.

Dart TUI documents useful editing, message, selection and lifecycle facilities, not verified coverage or accessible behavior for all 39 specimens. Inspection of extracted archived program.dart confirms enableWindowsVtInput occurs before Dart echo/line setters in the local patch. An equivalent current upstream fix remains unconfirmed: indexed package/version evidence was inconsistent, mutable API pages were not pinned to a verified implementation, and a related upstream issue does not establish restoration ordering. Dependency source verification and exact restoration regression tests remain required before adoption; no platform or assistive-technology tests were run.

The report inspected the atlas generator, local backend notes and selected complete files extracted by the parent from 8483a5a343bb595fdbeb3b3b5881e5233c285e90. It did not independently inspect every scenario implementation or rerun historical tests. The later human clarification that DateInput includes slash-separated date entry is recorded in the specialized-input ticket and current inventory; the report's general DateInput open questions do not supersede that requirement.

Research-derived design questions fit the existing shared-contract, family and readiness tickets. Resolving this research ticket does not approve any binding, new public API, fallback mode, backend release or support claim.

## Question

For the 39 specimens in doc/theme-components.md other than StepperForm, what interaction precedents and implementation constraints should inform later design? Inspect the atlas specimens and archived backend evidence locally, then investigate primary sources for Dart TUI's relevant event, editing, rendering and lifecycle capabilities and any current fix equivalent to the documented Windows restoration patch. Group overlapping controls without deciding their final public API. Cover navigation, selection versus focus, submission/cancellation, validation, feedback-only components, complex controls and discoverability. Use official CLI/library sources and standards as precedents; distinguish terminal facts from GUI/web analogies. Produce a traceability table covering all 39 specimens, citations, feasibility gaps, and open decisions. Do not implement components.
