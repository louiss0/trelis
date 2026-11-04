# Specify locale-calendar DateInput interactions

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 07, 15, 16
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Established human requirements

- DateInput remains slash-based, not a calendar-grid or slash-to-open shortcut.
- Follow effective system date conventions automatically, show prominent resolved format instructions and allow explicit override. Do not silently impose Y/M/D.
- Honor the locale's calendar, including non-Gregorian systems; do not silently reinterpret non-Gregorian year fields as Gregorian.
- Accept ASCII plus the resolved locale's decimal digits; reject mixed-script numbers. Locale digit parsing is a stated component-specific interpretation, not universal text normalization.

## Answer

Confirmed by the human after live discussion. This resolves the locale-calendar DateInput interaction contract, not a public Dart type, calendar-provider implementation or qualified platform claim.

### System resolution and supported overrides

- Preserve slash-based entry; no calendar-grid or slash-to-open interaction is introduced.
- Explicit supported override takes precedence over automatic resolution. Otherwise follow the executing user/process's effective system date conventions, not a guessed locale name or physical workstation location.
- Resolve calendar/variant, field order/year model, numbering system, era/month requirements, short-year interpretation and source metadata through the qualified platform/provider path.
- Windows user date overrides, macOS current effective preferences and Linux date-category context must not be replaced silently by stock locale data.
- Freeze one coherent resolution snapshot per prompt; re-resolve for later prompts. Preference changes cannot reinterpret a live draft automatically.
- Unsupported, unresolved or ambiguous settings require an explanation and explicit supported calendar/format override before editing. Never silently fall back to Gregorian, another order or a generic ISO input profile.
- Advertise actual calendar/provider/data versions and qualified date ranges. Non-Gregorian support must include genuine qualified operation, not rejection of every such setting followed by Gregorian.
- Unknown variants, year models, calendars or digit systems outside the declared capability envelope are unsupported, not opportunities for silent substitution.

### Slash body and explicit calendar context

- Numeric slash fields follow the resolved supported calendar order. Adapt native separators deliberately to / and explain the adaptation.
- Show full field labels/order, accepted widths and digit sets, calendar/variant, year meaning, era/month identity context, short-year window where applicable, and an example generated for that same qualified profile.
- Keep era and leap/intercalary month identity in explicit reviewable context choices outside the numeric body when needed.
- Require unambiguous context before submission. Do not silently choose the current era, an ordinary month in place of a leap month or an unrelated Gregorian year.
- Preserve the actual month identity/leap state, not merely an ordinal integer that another provider could interpret differently.
- Pattern symbols/models such as calendar year, week-year, year-of-era, related Gregorian year and cyclic year are not interchangeable. If a numeric slash profile cannot express the discovered model unambiguously, require an explicit supported override rather than discarding necessary identity.
- Textual/native-format adaptations must have a qualified unambiguous mapping and be disclosed; no claim that three bare integers describe every calendar.

### Short-year interpretation

- Honor the system's resolved century/reduced-year window only when its exact per-calendar meaning is discoverable, frozen and prominently displayed.
- If that interpretation is unavailable/ambiguous, use the explicit supported-override path; do not invent a moving window or silently force full-year input.
- Distinguish a short year-of-era from a reduced-year century rule. Do not infer semantics merely from digit count.
- Review shows the expanded fully resolved calendar year, not just the short original token.
- Do not borrow today's day/month/year context to complete a missing field.

### Digit policy

- Accept ASCII plus the resolved locale's declared decimal-digit repertoire.
- Each numeric field uses one repertoire consistently; reject mixed-script numbers within that field.
- Different fields may independently use ASCII/native digits; do not impose an additional whole-date uniformity restriction.
- Interpret accepted digits within this component, preserving the draft rather than silently rewriting text globally.
- A calendar and numbering system are separate. Do not assume every numeral system provides the ten decimal digits the parser needs.
- Labels/examples and bidirectional rendering must make logical field order understandable, not rely solely on visual slash placement.

### Editing and navigation

- Rich direct entry and labeled segment/context controls are available without a mouse or required enhanced modifier keys.
- Tab traverses fields/context/actions. Provide discoverable reverse/context navigation under actual delivered-key capabilities.
- In rich numeric entry, / leaves a structurally complete current segment and moves to the next without submission.
- Do not use slash to skip an empty required field, carry values or submit at the final separator.
- Linear mode enters the full slash body with literal delimiters and has explicit context-selection/review/edit/submit actions.
- Shared literal-command quoting applies at its declared boundary; identified paste stays data and cannot become navigation/submission commands.
- Up/Down adjusts the current segment locally and stops at its limits without carrying into another field.
- Changing year/month/context retains dependent field data even when it becomes invalid. Explain required correction and block acceptance.
- No silent day clamp, era replacement, leap-month substitution or overflow into another month/year.
- Defaults have an unambiguous declared calendar interpretation and must actually be editable. Do not use placeholder-only or pending-default acceptance as a capability substitute.
- No automatic today/current-era filling to complete incomplete input.
- Context/order/window overrides after editing preserve the original draft with its original interpretation and require deliberate review/re-entry/re-encoding. The same characters cannot silently become an accepted date under a different context.

### Strict validation

- Require complete input consumption, required context and a valid date inside the qualified calendar/provider/range.
- Verify actual era transition boundaries and contextual year/month/day ranges, including intercalary identity, rather than checking only independent integers.
- Reject overflow, unsupported ranges, invalid era dates and nonexistent leap months instead of relying on lenient DateTime/calendar construction.
- Conversion must round-trip the accepted calendar fields, era/year model, month identity/leap state and day without normalization/substitution.
- Preserve invalid/incomplete drafts for correction; provide persistent textual errors identifying the affected field/context.
- No timestamp/timezone is inferred to make an invalid or underspecified civil date acceptable.

### Review and accepted meaning

- Both modes validate the body and then require explicit review/submission.
- Review exposes the fully interpreted native-calendar date, era/month identity, expanded year and a separately labeled proleptic-ISO date-only encoding.
- Edit returns to retained values and context; cancellation/interruption/EOF do not accept the date.
- Accepted meaning retains a defined canonical civil-date identity plus input calendar/variant, era/year, month identity/leap state, day and conversion provenance.
- The canonical proleptic-ISO date/day identity is an encoding of the converted civil date under the qualified rules, not a claim that Gregorian fields were entered.
- No invented midnight, UTC offset or public timestamp is part of the answer. Public Dart representation is not chosen here.
- Any internal instant-based provider adapter needs explicit isolated conversion conventions and round-trip verification; convenience APIs cannot change public date-only meaning.

### Verification and handoff

- [Investigate system date conventions across desktop platforms](15-system-date-conventions.md) and [Investigate calendar-aware slash date entry and date-only results](16-locale-calendar-feasibility.md) hold evidence and limitations, not observed operational support.
- Pin exact source/provider/data and verify source-to-profile mappings, historical/cutover/range rules, era transitions and month identity before declaring a calendar configuration qualified.
- Cover genuine non-Gregorian cases, era/leap/intercalary behavior, century-window endpoints, ASCII/native digit tokens, field-order ambiguity, invalid-date retention, slash navigation and context overrides.
- Verify default editing and both review/submission flows in plain-rich and linear modes under the resolved Windows Terminal + NVDA whole-library gate.
- Cross-platform implementation remains required; this does not assign the human manual macOS/Linux testing or certify untested OSes/providers.
- Failure of a promised capability is a blocker or explicit supported-override condition, not permission to erase the requirement silently.
## Question

Given system-date and calendar feasibility research, what exact calendar-aware DateInput interaction contract provides equivalent rich/linear tasks? Decide supported-calendar envelope and unknown/failure policy, source/override precedence, slash field/era representation, year/month/day ranges and leap-month identity, editing/adjustment and rollover behavior, format/digit labels and examples, strict invalid/incomplete input, canonical date-only result semantics, and verification requirements. Preserve the established human requirements above and do not claim unperformed calendar/OS/accessibility support.
