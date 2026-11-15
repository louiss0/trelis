# Specify mask, duration and cron input contracts

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 05, 19
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. This resolves MaskedInput, DurationInput and CronInput only. The map's Out of scope section records removal of RegexInput and deferral of regex-based validation; this ticket does not introduce either feature.

### Shared boundaries

- Follow resolved grapheme-aware editor, literal-command, paste, actual-default capability, validation, cancellation and lifecycle rules.
- Keep original draft, interpretation, validation outcome and optional preview distinct. No silent filtering, truncation, case conversion, reclassification or normalization.
- Show active mode/profile, constraints and errors as reviewable text in rich/linear modes.
- Preserve correction state and distinguish optional absence from a successfully entered value. Numeric zero is not cancellation.
- These are future implementation/conformance requirements, not operational or accessibility proof.
- [Research mask editing, regex safety, duration and cron semantics](19-mask-pattern-duration-cron-evidence.md) includes the evidence/addendum and explicit historical-regex note. Web mask libraries are analogies, cron references have version/access limitations, and no parser/platform/assistive-technology tests were run.

### MaskedInput: declared format model

- Support fixed templates and adaptive masks. A format mask is not secret hiding, secure storage or safe-logging protection.
- Caller declares a fixed template or finite named candidate set, editable-slot rules/repertoires and literal separators.
- Keep raw slot data, formatted value and selected template identity distinct in the accepted/re-editable meaning; no public Dart shape is selected.
- Literals are presentation, not editable slot data. Do not silently strip user punctuation or change case to satisfy a template.
- Required-slot completeness is explicit. Incomplete/invalid drafts remain correctable and cannot submit as complete values.
- Slot navigation/deletion is grapheme-aware and distinct from terminal display width. Explain slot position/rules with text, not merely placeholder characters or color.

### MaskedInput: adaptive selection and editing

- Automatically activate a candidate only when uniquely fitting without data loss. Never silently tie-break by configuration order.
- Multiple fitting interpretations/candidates require explicit visible choice before submission; identify candidates readably in both modes.
- Replacing/deleting/pasting can reopen ambiguity. Retain the draft and expose that state rather than assuming an earlier template is still intended.
- A template switch preserves raw data/logical editing state and announces the selected template. If safe preservation is impossible, require explicit resolution rather than rewriting/dropping data.
- Rich typing overwrites the focused stable editable slot. Backspace/Delete clear previous/current editable slots without shifting subsequent data.
- Navigation skips literals; input processing does not silently remove characters merely because they resemble literals.
- Reject over-capacity edits without silent partial insertion; preserve useful correction state and the shared oversized-input policy.
- Linear mode provides equivalent raw/formatted/template review, explicit candidate selection, per-slot correction and /done validation/submission. Explain active actions and quoting; editing existing values requires a capable initial-value editor.
- Raw/formatted initial values and paste need a declared interpretation. Accept raw/formatted decoding automatically only when it is unambiguous and produces the same slot/template meaning.
- If valid interpretations differ, preserve the paste and ask for raw/formatted/template choice. Do not strip all punctuation or inherit a mask library's silent skip-invalid default.
- Identified paste remains data, never commands; original content must not disappear through adaptive dispatch.

### DurationInput: explicit modes and notation

- Caller selects elapsed or calendar-relative mode before entry. Do not infer/switch mode from a unit or reinterpret an existing draft automatically.
- Human unit-token grammar initially; no implicit ISO-style duration or clock shorthand parser.
- Amounts use ASCII digits and dot fractions, without grouping/locale guessing. This is a deliberate grammar boundary separate from NumberInput's system-localized conventions.
- Case-sensitive elapsed units: w, d, h, m, s, ms, us. Calendar mode additionally permits y and mo.
- m means minutes, mo means months. Advertise exact tokens; do not invent aliases or treat uppercase M as an undeclared alternative.
- Nonnegative by default. Zero is valid unless an explicit minimum forbids it. Signed mode is explicit and uses one global sign for the value; reject mixed per-component signs.
- Reject duplicate units instead of silently combining repeated entries. Retain the draft for correction.
- Preserve entered spelling/order for editing. Component tuples are not an ordered calendar-arithmetic program; do not turn token order into hidden application semantics.
- State bounds/resource/precision constraints and validate before any narrowing construction/overflow.

### DurationInput: elapsed semantics

- Elapsed d is exactly 24 hours; elapsed w is exactly seven such days. No local-calendar/DST inference.
- h/m/s/ms/us have their stated fixed-unit relationships.
- Represent the interpreted span at exact microsecond resolution; fractions are accepted only when exact conversion produces integer microseconds.
- Reject sub-microsecond or out-of-range values; no rounding, truncation or reliance on a native integer overflow.
- Quantity components are durations, not clock fields; do not silently wrap them into a different value.
- Preserve the original draft while showing a labeled equivalent elapsed interpretation.
- Do not promise scheduler/clock wake-up accuracy merely because the value has microsecond resolution.

### DurationInput: calendar-relative semantics

- Accept an unapplied period containing whole y/mo/w/d components and elapsed sub-day components.
- Calendar date components are whole quantities; fractional sub-day quantities follow exact microsecond conversion.
- Preserve the calendar component meaning. Do not reduce months/years to fixed days/seconds or silently replace a calendar day with 24 elapsed hours.
- Collect/review the period without inventing an anchor, timezone, endpoint or elapsed total.
- Applying/totaling the period belongs to the caller initially. No built-in anchored calendar-arithmetic preview is promised.
- The caller must supply calendar/reference/order/overflow/DST policies when it later applies the period; this component does not silently select them.
- Do not convert a period into Dart Duration merely because that type is convenient. Public result types are not selected here.

### CronInput: explicit expression profiles

- Support explicitly selected Unix five-field and Quartz profiles. Never autodetect by field count.
- Unix profile: declared Cronie-style five-field expression subset, minute/hour/day-of-month/month/day-of-week, with documented ranges, lists, steps and names.
- State the profile's exact weekday numbering and day-combination/wildcard rules, including stepped-day cases. Do not assume matching rules from a normalized value set or generic POSIX label.
- Exclude Unix command text, environment directives, random extensions and macros initially.
- Quartz profile: six required fields beginning with seconds and optional year, with declared version/range, field meanings, weekday numbering, day-field requirements and supported special tokens.
- Validate Quartz-specific tokens only where the profile permits them; never import them into the Unix profile or reinterpret both day fields using Unix rules.
- Publish the actual qualified parser/profile date/year bounds rather than inheriting an undocumented moving limit.
- Return/preserve the expression together with its declared profile meaning. No expression extraction from a crontab command line.
- Collect schedules only: no registration, execution, daemon configuration or external side effects.

### CronInput: syntax acceptance and optional preview

- A locally valid expression may be accepted without calculating a next run.
- Preview is explicitly configured, not implied by parser success or the atlas's example.
- Require selected dialect/provider, explicit IANA zone and relevant timezone-data/provider version, reference instant, finite result count, start/end instants and work budget before enabling preview.
- Keep the reference/context snapshot coherent; do not silently reinterpret the draft as the clock/preferences change.
- Next means strictly after the declared reference instant, within the stated search bounds.
- Use an explicitly declared civil-time matching preview with the selected profile's field/day rules.
- Skip nonexistent matching local times. Include both distinct instants of a repeated matching local time.
- Label the policy and context. Do not claim exact Cronie/Quartz daemon execution, clock-change, misfire or job-delivery emulation.
- Distinguish no match within horizon, exhausted budget, unsupported range and provider error. A bounded search is not proof that an expression can never run.
- No hidden arbitrary horizon/default budget. Missing preview configuration is disclosed; do not silently guess the system zone or fall back to another engine.
- With preview enabled, linear mode provides review/edit/preview/submit actions. Lack of a preview does not secretly rewrite the expression or become a successful preview.
- Preserve the expression on every error; syntax, matching preview and actual execution are separate evidence categories.
- Keep work bounded and the interaction/cancellation responsive; a timer that merely stops waiting must not be advertised as proof that computation stopped.

### Conformance and qualification

- Test masked literals versus data, raw/formatted ambiguity, candidate switching after edits, stable slot overwrite/clear, graphemes, complete/incomplete masks, paste capacity and actual default re-editing.
- Test duration token/prefix distinctions, ASCII syntax, duplicate/global-sign rejection, exact fractional conversions, range limits, zero, and elapsed/calendar separation without accidental arithmetic.
- Test each cron profile independently, including day rules/special tokens, invalid fields, known sparse/impossible calendar combinations, explicit zones, DST gaps/folds, strict-after reference behavior and bounded-result distinctions.
- Pin exact implementation/provider sources before claiming conformance; source excerpts and documentation alone do not qualify engines.
- Apply the resolved Windows Terminal + NVDA plain-rich/linear whole-library gate. Current scope is 38 components; no new standalone regex input/validation task is introduced.
## Question

For MaskedInput, DurationInput and CronInput, what formats/dialects, literal-versus-formatting behavior, editing actions, interpretation context and feedback constitute the interaction contract? Cover fixed/adaptive cursor/paste mapping for masks, elapsed/calendar-relative duration units/precision/context, and explicitly selected Unix/Quartz cron dialect/timezone/reference-clock/DST preview semantics. Define rich/linear task equivalents, meaningful errors and command extensions without treating the atlas as implemented behavior.
