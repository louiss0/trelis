# Trelis accessible interaction handoff

Trelis is a prompt library. This summary orients implementation work to the
research-backed interaction contracts. **No component implementation or
accessibility qualification has been performed by this planning effort.**

The implementation specification is
[Trelis accessible terminal prompt components](../.scratch/trelis-accessible-prompts/spec.md).
The canonical decision authority is the
[Wayfinder map](../.scratch/trelis-accessible-prompts/map.md) and its named
resolved tickets. This summary does not duplicate or replace their details.
The [research index](research/index.md) links all eight cited reports and their
exact source revisions.

## Current scope

The atlas retains **40 historical specimens**. Current scope is **38
components**:

- [Text and structured-input interactions](../.scratch/trelis-accessible-prompts/issues/05-editing-prompt-contracts.md):
  `TextInput`, `Password`, `Multiline`, `Autocomplete`, `TagInput`, plus shared
  editing rules.
- [Choice and hierarchical-navigation interactions](../.scratch/trelis-accessible-prompts/issues/06-choice-and-navigation-contracts.md):
  `Confirm`, `Select`, `MultiSelect`, `SearchSelect`, `Checkbox`, `Radio`,
  `TreeSelect`, `Toggle`, `TimezoneSelect`, `SortableSelect`, `CommandPalette`.
- [Specialized value and key-capture interactions](../.scratch/trelis-accessible-prompts/issues/07-specialized-prompt-contracts.md):
  `Slider`, `RangeSlider`, `TimeInput`, `PathInput`, `FilePicker`,
  `DirectoryPicker`, `Keypress`, `KeyChordInput`.
- [Accessible text and progress feedback](../.scratch/trelis-accessible-prompts/issues/08-feedback-contracts.md):
  `Text`, `Progress`, `Spinner`, `MultiSpinner`.
- [Numeric, network and color input contracts](../.scratch/trelis-accessible-prompts/issues/13-numeric-network-color-contracts.md):
  `NumberInput`, `PortInput`, `IPAddressInput`, `URLInput`, `EmailInput`,
  `ColorInput`.
- [Mask, duration and cron input contracts](../.scratch/trelis-accessible-prompts/issues/14-mask-pattern-duration-cron-contracts.md):
  `MaskedInput`, `DurationInput`, `CronInput`.
- [Locale-calendar DateInput interactions](../.scratch/trelis-accessible-prompts/issues/17-locale-calendar-date-contract.md):
  `DateInput`, including actual non-Gregorian-calendar support under qualified
  configurations.

`StepperForm`, multi-prompt forms, `RegexInput`, and regex-based input
validation are out of scope. Built-in anchored calendar-period arithmetic and
ISO-style duration profiles are deferred: `DurationInput` collects fixed
elapsed spans or unapplied calendar periods.

## Shared contract

[Choose Trelis's shared accessible interaction contract](../.scratch/trelis-accessible-prompts/issues/04-shared-accessibility-contract.md)
holds the complete rules. At a glance:

- Every interactive component has rich and linear interactions with equivalent
  task outcomes; neither is presumed accessible without testing.
- Mode selection occurs before prompting. Current explicit user choice wins,
  then saved user preference, application preference and automatic selection.
- Automatic rich mode requires actual capabilities; an unavailable explicitly
  requested rich mode fails clearly rather than silently downgrading.
- Prompt/feedback output uses stderr by default. Check the actual input/output
  streams separately; do not consume redirected input or select defaults
  implicitly.
- Escape backs out of transient rich layers and cancels at the root; Ctrl+C
  interrupts the whole prompt. Neither submits an answer or terminates the
  application on its behalf.
- Enter/Tab component exceptions are advertised and have portable alternatives.
  Essential actions cannot depend solely on mouse, color, animation, decoration
  or unavailable key combinations.
- Validation retains drafts, uses persistent textual correction guidance, and
  never accepts pending/stale asynchronous validation as successful.
- Secrets are not replayed through errors, summaries or transcripts. Feedback
  components do not acquire artificial focus or operation-cancellation
  responsibility.
- Terminal state is restored on controllable exit paths, including repeated
  prompts. Forced process termination is not claimed as a cleanup guarantee.

[The shared linear command and literal-input grammar](../.scratch/trelis-accessible-prompts/issues/10-linear-command-grammar.md)
defines exact `/help` and `/cancel`, narrow backslash quoting, and explicitly
advertised component commands. Literal answer data is separate from display
encoding and identified-paste provenance; display escapes must never leak into
answers. Hidden secret entry, supplied answers and identified paste are literal.
Unframed paste remains an explicit limitation.

The root [glossary](../GLOSSARY.md) defines project vocabulary, including rich
versus linear interaction, civil dates, calendar periods, logical key gestures,
canonical tags and feedback components.

## Component construction and grouped values

The readiness discussion establishes the creation boundary without prescribing
every component signature:

- Public components, including feedback components, are classes. Construct a
  component, then explicitly invoke its prompt/presentation method.
- Positional component parameters are permitted; use records for coherent
  grouped values or settings. Do not introduce one option-holder class per
  component.
- Use named record fields where they make related values self-describing;
  avoid large anonymous positional tuples. Exact record shapes/signatures are
  per-component implementation design.
- Records with invariants are wrapped in extension types whose private parsing
  path validates them. Where a validated grouped type is required, an
  unvalidated raw record is not an accepted substitute.
- Invalid configuration fails at its creation/validation boundary. It is not
  silently corrected and is not confused with a correctable user-input error.
- Construction does not acquire input, change terminal state or render. The
  prompt/presentation method owns the session and terminal lifecycle.
- Each invocation starts a fresh prompt session; one instance does not run
  concurrent sessions. A previous session's accepted answer is not replayed
  implicitly.
- Records are appropriate for accepted multi-field values. Success,
  cancellation, interruption, input-ended and unavailable outcomes remain
  explicitly named states, not a single record containing mostly absent
  alternatives. Exact outcome-type names are implementation design.

This is a component-creation model, not permission to implement the library
inside this planning ticket.

## Required implementation gates

[The accessibility verification matrix and evidence gates](../.scratch/trelis-accessible-prompts/issues/11-verification-matrix.md)
holds the full future acceptance policy.

### Ownership and claim boundaries

- Implement cross-platform behavior for Windows, macOS and Linux.
- The user's manual test scope is **Windows Terminal + NVDA only**. Do not
  assign them Narrator or manual OS-compatibility testing.
- Automated analysis, unit/integration and platform-specific engineering checks
  target all three OSes where execution infrastructure exists. Unexecuted
  checks remain unverified, never reported as passing.
- Qualify environments incrementally, beginning on Windows. Do not infer
  untested OS compatibility from an implementation requirement or Windows pass.

### Before bulk component implementation

Run small **Windows Terminal + NVDA** probes in the `plain` rich profile and
linear mode. Establish actual editable defaults, literal/default correction,
meaningful labels/current state, error recovery, safe secret editing, bounded
status feedback, cancellation/interruption and terminal restoration.

A foundational failure reopens the affected design/backend decision and stops
bulk rollout. Do not silently weaken actual-default editing or nonvisual task
completion to make a backend work.

### Before a whole-library accessibility claim

Require all **38** components to pass their applicable representative tasks in
both `plain` rich and linear modes, with applicable no-color/nonanimated checks
on the exact Windows Terminal/NVDA environment. This is a whole-library claim,
not a component-by-component accessibility certification program.

Record the actual OS, terminal, shell, reader/version/settings, keyboard/layout,
locale, rendering mode, input protocol and exact application/backend/provider
revisions. Include experienced NVDA usability review and retain sanitized
task evidence. Do not record raw secrets.

Pin and inspect the actual dependency implementation. Verify any Windows
restoration fix by exact source and regression checks—not by a related issue,
changelog or historical patched prototype alone. Synthetic decoding, visual
screenshots and documentation capabilities cannot substitute for nonvisual task
completion.

An explicitly unsupported configuration may report unavailable. That cannot
waive a capability promised by the qualified baseline. A required failed or
incomplete task blocks the claim.

### Regression

The first qualification requires the full baseline. Later changes use
impact-based manual reruns plus release smoke checks; broad input, rendering or
backend changes can trigger a full rerun. Automated regression checks remain
active. New layouts, terminals/readers, OSes or configuration envelopes are not
silently added to the claim.

## Where implementation begins

1. Read this summary, the map, shared contract and selected component ticket.
2. Use the research index for evidence and version-specific limitations. Follow the component-construction model above: classes for behavior, records for grouped data, and validated record extension types rather than option classes.
3. Resolve and inspect actual backend/editor/calendar/parser candidates and
   their source revisions; these are intentionally not preselected APIs.
4. Run the early Windows + NVDA probes before implementing the whole suite.
5. Implement against the per-component answers and contract-specific cases.
6. Keep automated platform checks and sanitized task evidence distinct from
   manual NVDA qualification.
7. Do not make the whole-library accessibility claim until every required gate
   has actually passed.

The remaining work is execution and evidence-gathering, not an unstated
interaction-design requirement hiding in the map.
