# Agree on interaction-specification readiness and verification gates

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 05, 06, 07, 08, 11, 13, 14, 17
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed ready for implementation handoff by the human after live discussion, independent review, scope/coverage checks and a final component-construction decision.

### Coverage and contradictions

- All 38 currently in-scope specimens have resolved interaction contracts. The atlas retains 40 historical specimens; StepperForm and RegexInput are out of scope, and regex-based input validation is deferred.
- Resolved family tickets cover: text/editing, choices/navigation, specialized values/key capture, feedback, numeric/network/color, masks/durations/cron and locale-calendar DateInput.
- Shared interaction, linear grammar and verification contracts are resolved. All readiness blockers are resolved.
- Independent coverage review found no uncovered specimen, invalid dependency or missing internal artifact link.

Two substantive cross-component gaps were identified and resolved with the human:

1. Capable command-aware editors keep literal answer data separate from reversible display encoding and retain identified pasted-range provenance. Decode/recognize once at logical submission where permitted; representation escapes never become answer data through ordinary editing. [The shared linear grammar](10-linear-command-grammar.md) contains the addendum.
2. Single-choice and search-result focus has a deterministic default-first, then enabled, then available policy, including resumption and unavailable-focus rules. Focus is not selection; unavailable choices cannot be accepted. [The choice/navigation contract](06-choice-and-navigation-contracts.md) contains the addendum.

The cancellation glossary was corrected so rich layered Escape and direct linear /cancel are not conflated.

### Component creation and grouped values

The human's construction requirements are part of the handoff:

- Public components, including feedback components, are classes. Construct a component, then explicitly invoke its prompt/presentation method.
- Positional component parameters are permitted where useful. Records group coherent values/settings and are preferred over per-component option-holder classes.
- Use named record fields where they clarify meaning; avoid large anonymous positional tuples. Exact signatures and record shapes remain per-component implementation design.
- Records needing invariants use extension types with private parsing as their validation boundary. Unvalidated raw records cannot substitute for the required validated grouped type; components do not silently repair it.
- Invalid configuration is rejected at its creation/validation boundary, distinct from ordinary user-input correction.
- Construction does not acquire input, change terminal state or render. The prompt/presentation method owns the session/lifecycle.
- Each invocation starts a fresh prompt session, does not replay a previous answer and does not allow concurrent sessions on one component instance.
- Multi-field accepted answers can be records. Success, cancellation, interruption, input-ended and unavailable are explicitly named outcome states, not a record of mostly absent alternatives. Exact outcome type names are implementation design.

### Packaged evidence and handoff

- [Research index](../../../doc/research/index.md) links all eight reports and their exact original report commits/branches. The reports were consolidated through history on docs/trelis-interaction-research, retaining provenance.
- [Research and interaction handoff](../../../doc/trelis-interaction-handoff.md) is a visible navigation/orientation summary, not a second authority for interaction answers.
- The map and its tickets remain canonical; the root glossary records domain vocabulary.
- Historical 39-specimen/regex research remains historical; the current 38-component scope is consistent across the map, inventory and verification gate.

### Verification boundary and decision

- The required implementation direction remains Windows/macOS/Linux; the human's manual testing scope is Windows Terminal + NVDA only. Narrator and manual OS-compatibility tests are not assigned to them.
- Small early Windows/NVDA probes must prove actual editable defaults, correction, safe secret handling, status interpretation and safe lifecycle before bulk implementation.
- A public whole-library accessibility claim requires all 38 in-scope components in plain-rich and linear modes under the exact recorded Windows Terminal/NVDA environment and evidence gates.
- Actual backend/editor/provider revision selection, source inspection, conformance tests, implementation and qualification remain future handoff work. Unexecuted work is not a passing result.
- A failed feasibility gate reopens the affected design/backend decision through new planning; it must not silently weaken the agreed contract.

**Readiness decision: confirmed.** The route to implementation is clear, with no remaining in-scope interaction/construction fog for this map. The map is ready to be marked complete. This is not a claim that the library is implemented or accessibility-qualified.
## Question

Do the resolved contracts cover every in-scope specimen and every supported capability tier, with consistent cross-component behavior and concrete automated/manual acceptance checks? Resolve remaining contradictions, distinguish verified behavior from required future platform/assistive-technology tests, and agree whether the route is clear for implementation handoff. This ticket decides readiness; it does not implement or certify the library.
