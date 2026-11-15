# Choose the accessibility verification matrix and evidence gates

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion and an explicit correction of testing expectations. This selects the verification contract and future handoff gates; it does not execute tests or certify support.

### Implementation scope versus manual testing

- Cross-platform implementation for Windows, macOS and Linux remains required.
- The human's manual testing scope is Windows Terminal + NVDA only. Do not assign them manual macOS/Linux OS-compatibility work or mandatory Narrator testing.
- The human clarified that this correction does not reopen the resolved specialized-input contract.
- Qualify environments incrementally, starting on Windows. Broad compatibility and other OS implementations remain targets; do not imply observed support for untested environments.
- Engineering-owned automated build, analysis, unit/integration and platform-regression checks target all three OSes as execution infrastructure becomes available. Missing execution is unverified, never a passing result, and does not silently remove implementation requirements.
- A Windows accessibility qualification is not evidence of macOS/Linux compatibility or accessibility. Additional environments need their own evidence before broader claims.

### Initial whole-library baseline

- The unit of the initial public accessibility claim is the whole library, not individual components.
- Require every one of the 38 currently in-scope specimens to complete its applicable task suite in both the plain rich profile and linear mode, including applicable no-color/nonanimated behavior.
- Plain is the atlas's named minimal ASCII/monochrome structure, not a synonym for linear interaction. Its static design is not proof of accessibility.
- Individual case/component results may be tracked internally, but passing a few components does not authorize a public partial-library accessibility claim.
- Initial claim scope is limited to the exact qualified Windows Terminal/NVDA environment, output profiles and declared configuration envelope.
- Other terminal hosts, readers (including Narrator), rich structures, OSes, keyboard/input configurations and unsupported calendar/provider variants are not silently included.
- Additional rich structures stay outside the claim until verified. This limits evidence scope, not the requirement to implement the project.

### Exact environment and revision manifest

Before a qualification run, record and retain:
- Windows version/build, terminal version and actual shell/version.
- NVDA version and relevant speech/typing/progress/review settings.
- Keyboard layout/input method, locale, encoding and any transport/multiplexer.
- Application/library commit, Dart SDK, exact backend/dependency revision/archive identity and patch state.
- Rich structure/mode, color/animation settings, dimensions and applicable terminal/input protocol configuration.
- Relevant locale/calendar/timezone/parser data/provider versions and qualified configuration/range when needed.

Pin claims to the actual run manifest and tested revision, not rolling latest documentation or an untested future version. Do not imply all Windows/NVDA versions passed.

Inventory observed during planning, NOT an interaction test:
- Windows 11 Home 10.0.26200/build 26200.
- Installed Windows Terminal package 1.24.12741.0.
- Harness Windows PowerShell 5.1.26100.9711.
- No WT_SESSION marker in the harness and no running NVDA/Narrator processes returned by the process query.

These inventory facts do not identify a completed visible-terminal test or establish reader installation/usability. The future qualification manifest must capture the actual test host.

### Gate 1: early feasibility before bulk implementation

Run small Windows Terminal + NVDA probes in plain-rich and linear presentations before generalizing the component architecture:
- Actual editable initial values, including deletion to empty, correction and literal command/backslash collisions.
- Discoverable labels/instructions, current/focused/selected state and reviewable context.
- Invalid input, persistent errors and correction without lost state.
- Hidden secret editing, explicit prefill/masking options, safe action stages, application-output safety and documented NVDA echo behavior.
- Meaningful bounded status/progress updates and final outcome review.
- Cancellation/interruption, EOF, recoverable errors and terminal restoration.

A foundational failure stops bulk rollout and reopens the relevant design/backend choice; do not silently weaken actual-default editing, nonvisual task completion or another agreed contract.

This is a required future implementation-handoff gate, not execution or a prototype deliverable within the current planning map.

### Gate 2: complete initial baseline

For every in-scope component, verify the applicable tasks rather than only recognizing a screenshot:
- Discover purpose, constraints, default/current value and actions without requiring sight.
- Enter/edit/select/reorder or interpret feedback as appropriate.
- Distinguish focus from selection, provisional state from accepted result, unavailable/locked state from active state, and observed from declared keys.
- Obtain/review help and context.
- Trigger validation/no-match/empty/unavailable/async error states, understand them and recover.
- Complete the intended task with the correct result and review its final outcome.
- Cancel/interrupt safely and distinguish EOF from submission.
- Exercise applicable rich/linear equivalents, no-color/nonanimated output, narrow/resize cases and actual clipboard paste separately from synthetic protocol injection.

Include the contract-specific risk cases: graphemes versus width, defaults and quoting, mixed/hidden selections and count limits, anchors/tree traversal, tag normalization/duplicates, key provenance/reserved keys, filesystem/link/race errors, and declared calendar/digit/provider support once those contracts settle.

Feedback-only components do not acquire artificial focus or key handling just to fit a checklist.

Include experienced NVDA usability review before the public claim. An automated decoder test, sighted visual pass or hearing some speech is not proof of nonvisual task completion.

A required failed/incomplete task blocks the whole-library claim. An unavailable result is acceptable only for an explicitly unsupported configuration; it cannot waive a capability promised by the baseline.

### Gate 3: backend and lifecycle regression

- Inspect/pin the exact candidate dependency implementation before relying on documented capabilities.
- Verify any Windows restoration fix by exact source comparison and regression behavior, not a related issue/changelog alone.
- Retain original/final native console-mode and cursor checks; test submission, Escape, Ctrl+C/process interruption, EOF, recoverable errors and repeated prompt sessions.
- Verify ownership of input/output, mode negotiation, stream redirection and cleanup, including no concurrent competing input readers.
- Do not treat the archived patched Dart TUI 3.0.0 success as evidence that an unpatched/current release is correct or that macOS/Linux behavior was tested.
- Add automated platform-specific lifecycle checks on the relevant runners. Unexecuted checks retain their explicit evidence gap rather than becoming user-owned manual OS tasks.

### Evidence artifacts and decisions

Keep sanitized case evidence with:
- Case/task identifier, component and mode/profile.
- Exact manifest/revision and configuration.
- Expected and observed behavior, result and reproduction details.
- Failures, workarounds, known limitations and unavailable/unverified cases.
- Sanitized output/transcript or other useful observations; never raw secrets.
- Reviewer/tester context appropriate to usability review without requiring unnecessary personal information.

Documentation capabilities, implementation inspection, synthetic tests, real keyboard tests and actual NVDA task completion are different evidence categories. Do not promote one into another.

The whole-library qualification record must show coverage of all 38 currently in-scope specimens and both designated modes; no unsupported universal accessibility/OS claim.

### Regression after qualification

- First qualification requires the complete baseline.
- Later manual checks are impact-based affected-component/mode reruns plus release smoke checks.
- Relevant broad backend/input/rendering/interaction changes can require a full baseline rerun.
- Record tested revision, change-impact rationale, rerun coverage and remaining limitations.
- No automatic extension to new layouts, terminals/readers, OSes or untested configurations.
- Keep automated regression checks active; tests do not authorize stale claims when user-visible behavior has changed.

### Scope maintenance

The human subsequently removed RegexInput and deferred regex-based validation; see the map's Out of scope section. The whole-library gate now covers 38 components, with its quality criteria unchanged. Older research/report counts remain historical.

### Planning boundary

This ticket decides the gates, scope and ownership only. Actual implementation, probes, infrastructure setup and qualification happen after handoff; they are not falsely marked complete by closing this decision.

The value-format and calendar tickets subsequently supplied their acceptance cases; see the readiness decision for final cross-contract consistency and handoff scope.
## Question

Which exact Windows/macOS/Linux terminal, screen-reader, keyboard-layout and transport environments form the initial verification matrix, and what per-mode/per-component task evidence is required? Distinguish broad-compatibility intent from verified support, define required lifecycle/backend-revision checks and manual usability gates, and identify precise access/prototype prerequisites without claiming unperformed tests.
