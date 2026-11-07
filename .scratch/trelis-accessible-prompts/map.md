# Trelis accessible prompt interaction specification

Labels: wayfinder:map
Status: complete

## Destination

Settle a research-backed interaction specification for the 38 currently in-scope specimens in doc/theme-components.md before development (excluding StepperForm and RegexInput): shared and component-specific keyboard behavior, screen-reader access, compatibility/fallback rules, and verification criteria for Windows, macOS and Linux.

## Notes

- The project is now called **Trelis** and remains a prompt library. Package/repository renaming is not part of this effort.
- Planning only: decisions, not component implementation. Research and readiness questions were resolved before implementation; qualification probes remain future work.
- Broad terminal compatibility is a design goal, not universal qualification. Cross-platform implementation is required; manual accessibility qualification belongs to the exact Windows Terminal + NVDA scope and does not assign manual macOS/Linux testing to the human. Separate desired support, documented capability and observed verification.
- DateInput is the existing slash-entry specimen, not a new calendar-grid component; its resolved interaction contract is indexed below.
- Keyboard operability and screen-reader usability are both required. Research simpler/linear alternatives without assuming a particular fallback design is already approved.
- Inventory: [theme specimens](../../doc/theme-components.md); existing direction and Windows patch evidence: [backend notes](../../doc/terminal-backend.md). Dart TUI is an existing direction, not an accessibility guarantee.
- Consult grilling and domain-modeling for decision tickets; research for research tickets; prototype if a human decision needs a concrete experiment. Skill files live under C:/Users/bvlou/.agents/skills/.
- Tracker: local Markdown per C:/Users/bvlou/.agents/skills/setup-matt-pocock-skills/references/issue-tracker-local.md. Child files live in issues/. Status open means unclaimed, claimed means in progress, resolved means closed. Claim by saving Status: claimed and an Assignee before work. Dependencies are Blocked by identifiers; query children rather than listing open tickets here. Lowest-numbered open, unclaimed child whose blockers are resolved is the next frontier ticket. Resolve with an appended Answer and a named context pointer here. Names, not bare IDs, are used in human-facing narration.
- Research uses isolated throwaway research branches/worktrees. Each research ticket points to its findings and exact revision. Source investigation is not real terminal or assistive-technology verification.
- Resolve at most one non-research ticket per session. HITL tickets require live human answers.

## Decisions so far

- [Terminal keyboard capabilities and cross-platform conflicts](issues/01-terminal-keyboard-evidence.md): legacy key collisions and input-layer interception require conservative essential actions; richer protocols, paste and Unicode behavior need explicit policy and end-to-end validation.

- [Screen-reader access and nonvisual terminal interaction](issues/02-terminal-screen-reader-evidence.md): documented terminal/assistive-technology capabilities do not prove prompt accessibility; research identifies linear-mode candidates, password risks and required real-environment validation.
- [Component interaction precedents and Dart TUI feasibility](issues/03-component-and-backend-evidence.md): all 39 specimens have traced interaction questions; archived patch ordering is confirmed, but current upstream equivalence and broad accessible backend behavior remain unverified.

- [Choose Trelis’s shared accessible interaction contract](issues/04-shared-accessibility-contract.md): confirmed equivalent rich/linear outcomes, user-first mode selection, explicit stream/input rules, layered cancellation, quiet correction/status policies and observed-evidence support gates.

- [Specify accessible text and progress feedback](issues/08-feedback-contracts.md): feedback-only components have explicit outcomes, literal safe text, nonanimated rich output, throttled linear progress and named concurrent-task summaries; cadence remains provisional pending validation.

- [Define the shared linear command and literal-input grammar](issues/10-linear-command-grammar.md): exact advertised commands use narrow backslash quoting; secret entry, supplied answers and identified paste remain literal, with unframed-paste limitations explicit.

- [Investigate editable defaults in linear interaction](issues/12-editable-default-feasibility.md): plain Dart/POSIX cooked reads cannot supply editable initial values; native/application-managed editor candidates require exact-source, stream, lifecycle and accessibility probes before support claims.

- [Specify text and structured-input interactions](issues/05-editing-prompt-contracts.md): confirmed grapheme-aware editors, actual editable defaults with explicit quoting, secret-safe action stages, separate suggestion acceptance, portable multiline actions and kebab/snake-only tags; detailed value formats remain separate decisions.

- [Specify choice and hierarchical-navigation interactions](issues/06-choice-and-navigation-contracts.md): confirmed provisional choices, discoverable disabled rows, stable references, predictable search, explicit tree traversal and anchor-aware reordering; Confirm defaults to No and palette execution remains application-owned.

- [Investigate system date conventions across desktop platforms](issues/15-system-date-conventions.md): OS date preferences cannot be inferred from one locale identifier; slash adaptation, calendar/digit scope and unknown-resolution handling need explicit policy and platform probes.

- [Specify specialized value and key-capture interactions](issues/07-specialized-prompt-contracts.md): confirmed precise stepped ranges, non-rolling time entry, literal resolved paths/read-only pickers and provenance-aware logical key capture; full locale-calendar DateInput was resolved separately after this ticket.

- [Investigate calendar-aware slash date entry and date-only results](issues/16-locale-calendar-feasibility.md): non-Gregorian entry needs bounded provider/calendar support and explicit era/leap-month identity; candidate engines and date-only representations remain unqualified until source/prototype verification.

- [Choose the accessibility verification matrix and evidence gates](issues/11-verification-matrix.md): confirmed Windows Terminal + NVDA whole-library qualification on plain-rich/linear profiles, early feasibility probes and impact-based regression; cross-platform implementation remains required without user-owned manual OS testing.

- [Research numeric and network/color value grammar boundaries](issues/18-typed-value-standards.md): standards expose parser permissiveness, effective numeric-preference requirements and distinct IP/URL/email/color semantics; remaining acceptance and normalization choices belong to the active value-contract ticket.

- [Specify numeric, network and color input contracts](issues/13-numeric-network-color-contracts.md): confirmed system-localized exact numbers, explicit port/IP scope, strict allowed-scheme URLs, internationalized bare email and precision/alpha-preserving sRGB entry without hidden repairs or external checks.

- [Research mask editing, regex safety, duration and cron semantics](issues/19-mask-pattern-duration-cron-evidence.md): mask selection/paste and calendar-period arithmetic need explicit policy; cron dialect/DST behavior cannot be inferred universally. Regex findings are historical and now out of scope.

- [Specify mask, duration and cron input contracts](issues/14-mask-pattern-duration-cron-contracts.md): confirmed explicit adaptive-mask ambiguity, elapsed/unapplied-calendar duration modes and bounded contextual Unix/Quartz matching previews without hidden rewriting or execution.

- [Specify locale-calendar DateInput interactions](issues/17-locale-calendar-date-contract.md): confirmed qualified system-calendar slash entry, disclosed short-year windows, explicit era/month context, preserved invalid drafts and reviewed date-only results without silent Gregorian fallback.

- [Research and interaction handoff](../../doc/trelis-interaction-handoff.md): navigation and implementation gates for all 38 resolved component contracts; detailed answers remain in their tickets.
- [Accessible terminal prompt component specification](spec.md): ready-for-agent implementation handoff, including public-behavior tests and native/NVDA qualification gates.

- [Agree on interaction-specification readiness and verification gates](issues/09-spec-readiness.md): confirmed all 38 contracts, cross-component consistency, component-class/record/extension-type construction boundaries and the complete research/handoff package. The map is ready for implementation handoff; execution and qualification remain future work.

## Not yet specified

No in-scope interaction or component-construction fog remains for this planning destination. Feasibility failures during future probes may reopen named decisions through a new map; they are not an unfinished route here. The visible research index and handoff summary are packaged under doc/. Exact component signatures, outcome-type names and implementation architecture beyond the agreed construction model are outside this destination.

## Out of scope

- RegexInput and regex-based input validation: the human removed standalone regex entry from this effort and deferred regex-based validation to later. Current scope is 38 components; earlier 39-component research is historical evidence, not a requirement to implement RegexInput.

- Built-in anchored calendar-period arithmetic and ISO-style duration profiles: excluded from the initial duration contract; collect unapplied periods and leave application/totaling to the caller.
- StepperForm and multi-prompt form orchestration: explicitly deferred while this effort defines standalone prompts and feedback.
- Component implementation, dependency migration, shipping a Windows backend fix, and actual package/repository renaming: beyond this planning destination.
