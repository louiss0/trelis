# Evidence for mask, pattern, duration, and cron input contracts

> Parent scope note: this investigation began before the human removed RegexInput and deferred regex-based validation. Regex material below is retained as historical research only, not an in-scope requirement. The active contracts cover MaskedInput, DurationInput and CronInput. The addendum reflects the selected adaptive-mask and calendar-relative modes.

**Research date:** 2026-11-03, host timezone UTC−05:00.  
**Scope:** Primary-source documentation and source-code evidence; no implementation, parser execution, platform checks, or assistive-technology testing.

**Evidence labels:** **Fact** identifies source-backed findings. **Inference** identifies implications for the proposed contract. **Open question** identifies decisions this research does not make.

**Version qualification:** Dart API pages, IMask’s guide, Inputmask’s repository, and Cronie’s `master` documentation are rolling sources, not pinned dependency versions. Quartz sources below explicitly identify their documentation versions. A downstream contract should record its actual dependency/runtime versions rather than treating these observations as timeless guarantees.

## Summary

1. A formatting mask is not a secrecy mechanism. Existing mask libraries illustrate editing and value-model choices, but their browser behavior does not establish terminal behavior.
2. Dart `RegExp` uses ECMAScript semantics, including backtracking. `Future.timeout` limits waiting, not computation; isolate termination is a request, not a documented hard real-time deadline.
3. Dart `Duration` represents fixed elapsed microseconds, not calendar months or years. Precision and representable totals depend on platform integer behavior.
4. “Cron” is not one grammar or one scheduling policy. POSIX, Cronie, and Quartz differ; timezone, reference instant, daylight-saving behavior, and search limits belong in the explicit contract.
5. These findings do not override the existing shared contract: preserve drafts, avoid silent transformations, provide rich/linear equivalents, use command-aware quoting, and keep checks local by default.

## 1. MaskedInput: formatting and editing, not secrecy

### Source-backed findings

**Fact — Formatting and typed values are distinct concepts.** IMask exposes `value` (formatted), `unmaskedValue`, and `typedValue`; typed masks such as number/date masks can provide a typed value, while ordinary masks treat typed and unmasked values alike. Its guide separates the mask model from its UI binding. [M1]

**Fact — Editing policy is configurable, not inherent in “mask.”** IMask documents overwrite mode, including a shift variant, and invalid-character skipping. The guide labels overwrite as available since 5.0, shift since 6.4.0, and skip-invalid mode since 6.5.0. Invalid-character skipping defaults to enabled. The guide also warns that validation must accommodate intermediate states rather than accept only the final completed string. [M1]

**Fact — Batch input has different hooks from per-character input.** IMask’s `prepare` processes an inserted string once, whereas `prepareChar` processes characters individually. Inputmask separately provides `onBeforePaste` preprocessing, `insertMode`, and `autoUnmask`; these are distinct controls rather than one universal paste behavior. [M1][M2]

**Fact — A displayed character need not be one code point.** Unicode UAX #29 defines grapheme-cluster boundaries for user-perceived characters, including sequences containing multiple code points. Its segmentation rules do not define terminal cell width. [M3]

### Implications and limits

**Inference — Define MaskedInput as format-constrained input, separate from secret input.** The cited mask libraries are concerned with formatting, validation, and value extraction. Their masking APIs do not establish confidentiality, encryption, redaction, secure storage, or safe logging. Naming a field “masked” must not imply any of those protections.

**Inference — Browser libraries are analogies only.** Their APIs demonstrate useful distinctions—insert/overwrite, batch paste, partial validity, display/raw/typed values—but do not prove terminal cursor movement, bracketed-paste behavior, grapheme-aware deletion, screen-reader announcements, or cell-width handling.

**Inference — Do not import silent skipping as a default.** A library’s skip-invalid or paste-preprocessing feature may conflict with the shared “no silent changes” contract. The contract should describe any proposed transformation and preserve the original draft rather than accidentally inheriting library defaults.

### Sharp open questions

- Is submission the display string, raw string, typed value, or an explicitly named combination?
- Are literals user-entered, automatically displayed, or part of the submitted value?
- What constitutes an editable slot: ASCII character, Unicode code point, or grapheme cluster? Which characters are accepted?
- What happens when insertion, replacement, deletion, or paste crosses literals or exceeds capacity?
- Is an incomplete draft retained with an explanation, or rejected only on submission?
- If formatting changes the draft, how is that change exposed without violating preservation and rich/linear equivalence?

**Not confirmed:** Neither library’s cited documentation establishes a comprehensive grapheme-cluster editing guarantee or any TUI accessibility guarantee.

## 2. RegexInput: dialect, Unicode, and enforceable limits

### Dart semantics

**Fact — Dart `RegExp` follows ECMAScript regular-expression syntax and semantics.** The API explicitly describes backtracking behavior and notes that browser compilation can use the browser’s regular-expression implementation. This is not a promise of PCRE, POSIX regular expressions, or another dialect. [R1]

**Fact — Constructor flags have explicit defaults:**

```dart
multiLine: false
caseSensitive: true
unicode: false
dotAll: false
```

Invalid pattern syntax throws `FormatException`. Unicode mode changes permitted syntax and Unicode interpretation; it is not an execution-safety switch. [R2]

**Fact — Matching is not necessarily whole-value validation.** `hasMatch` asks whether a match exists; matching APIs include searches and prefix matching. A contract must distinguish searching from accepting the entire value. [R1]

**Fact — Backtracking can be expensive.** Dart’s documentation demonstrates exponential behavior from nested quantifiers and polynomial behavior from sequential quantifiers. It warns that these patterns can permit denial-of-service attacks and that there is no general solution for all problematic expressions. [R1]

**Inference — Bound both pattern and candidate input.** Input limits reduce exposure but do not prove that an arbitrary pattern is safe. Unicode mode likewise does not turn the engine into a linear-time matcher.

### Timeout versus stopping work

**Fact — `Future.timeout` stops waiting, not the source computation.** The source future can complete later; its late result or error does not complete the timeout future. [R3]

**Inference — Wrapping synchronous regex matching in a future does not make it interruptible.** On one isolate, a long synchronous match can prevent the event loop from processing the timer that would report a timeout. A timeout wrapper alone therefore cannot substantiate a claim that validation work stops after a stated budget.

**Fact — Isolate termination has scheduling semantics.** `Isolate.kill` sends a shutdown request. Its default `beforeNextEvent` waits for the event-loop boundary; `immediate` requests shutdown as soon as possible, including during an event. The documentation does not supply a maximum termination latency or a general guarantee of interrupting native execution and cleaning up native resources. [R4]

**Fact — Platform support matters.** Dart’s concurrency documentation says Dart web does not support isolates and points to web workers for background execution. Flutter’s `compute` runs on the current event loop on web, and in a separate isolate on native platforms. [R5][R6]

**Inference — Isolation is stronger containment, not proof of a hard deadline.** A separately managed worker allows the supervising event loop to remain responsive and request termination. Whether an execution limit is enforceable requires a stated runtime, execution boundary, and termination guarantee; the cited APIs do not establish hard real-time interruption across every backend or native operation.

### Sharp open questions

- Does RegexInput collect a regex pattern or a value checked against an application-owned pattern?
- Which flags are fixed, exposed, or prohibited? Is validation search, prefix, or whole-value matching?
- What are the maximum pattern and candidate sizes, measured in which units?
- Is the promise “report after a budget,” “request worker termination,” or “computation has definitely stopped”?
- On unsupported backends, is risky validation unavailable, restricted to a safer subset, or explicitly unbounded?
- How are syntax errors, mismatch, budget exhaustion, and worker failure distinguished without discarding the draft?

**Not confirmed:** No cited Dart API establishes a universal millisecond bound for terminating arbitrary regex execution. Establishing one would require backend-specific guarantees, not merely `Future.timeout`.

## 3. DurationInput: elapsed quantities versus calendar periods

### Source-backed findings

**Fact — Dart `Duration` is a context-independent span.** It stores a total count of microseconds rather than retaining separate day/hour/minute components. A day is always 24 hours, regardless of daylight-saving transitions. [D1]

**Fact — Constructor units are fixed and additive.** Its parameters are integer days, hours, minutes, seconds, milliseconds, and microseconds. Values are combined; components need not be within normal clock-field ranges. Negative values are possible. [D2]

The corresponding exact unit relationships are:

| Unit | Interpretation for a Dart `Duration` |
|---|---:|
| microsecond | base unit |
| millisecond | 1,000 microseconds |
| second | 1,000 milliseconds |
| minute | 60 seconds |
| hour | 60 minutes |
| day | 24 hours |

These are API constants, not locale-sensitive calendar conventions. [D1]

**Fact — Representability is platform-dependent.** The constructor warns that a total not representable as an integer can overflow or lose precision. Dart native integers are signed 64-bit; Dart JavaScript integers use double-precision representation, with consecutive integer precision through 53 bits. Therefore the type does not offer one platform-independent, exact microsecond range. [D2][D3]

**Fact — Converting to larger units loses fractional information.** Properties such as `inMilliseconds` and `inSeconds` return whole units, truncating the remaining fraction rather than preserving arbitrary decimal precision. [D1]

**Inference — Months and years cannot be exact aliases for elapsed units without a new convention.** They are not constructor units. Calendar-relative “one month,” “next day at the same local time,” and fixed “24 hours” require different semantics and potentially an anchor date, timezone, and calendar policy.

**Inference — Microseconds are representation precision, not scheduler accuracy.** A `Duration` value does not establish clock resolution, wake-up accuracy, or an external system’s supported precision.

### Sharp open questions

- Is the field strictly fixed elapsed time, or does it also represent calendar-relative periods?
- What exact spellings and case distinctions are supported—especially `m` versus month, and `ms` versus minutes?
- If weeks are supported, do they mean exactly seven 24-hour days? Are months and years rejected or separately modeled?
- Are decimals accepted, and how are sub-microsecond values rejected or rounded?
- Are signs global or allowed on individual components? Are duplicate units and mixed signs legal?
- What exact portable range is promised, and are out-of-range values rejected before constructing a `Duration`?
- Does display normalization preserve the submitted draft and communicate any precision loss?

**Not confirmed:** There is no universal textual duration grammar supplied by Dart `Duration`. Accepting ISO-style periods, clock notation, or human abbreviations would be an additional product grammar, not a consequence of using this type.

## 4. CronInput: name the dialect and scheduling policy

### Dialect comparison

| Family | Source-backed characteristics |
|---|---|
| **POSIX crontab** | Five scheduling fields: minute, hour, day-of-month, month, day-of-week, followed by command text. Day-of-week uses 0–6, Sunday 0. The specification describes day matching using either day field when both are restricted. [C1] |
| **Cronie** | Documents five time fields; extensions include names, step syntax, Sunday as 0 or 7, `CRON_TZ`, and special strings such as `@reboot`, `@daily`, and `@hourly`. These are not evidence that every POSIX implementation supports them. [C2] |
| **Quartz** | Six required fields, beginning with seconds, and an optional year field. The 2.3 tutorial documents `?`, `L`, `W`, and `#`; day-of-week numbering is 1–7. Quartz does not offer POSIX-style unrestricted combination of specific day-of-month and day-of-week constraints: one normally uses `?` in one day field. [C4][C5] |

**Source limitation — POSIX:** The Open Group page could not be retrieved directly during this research. The cited text is a hosted reproduction identifying itself as the Open Group specification, not a source-owned live endpoint. Its edition is SUSv4 TC2/POSIX.1-2008-era material. POSIX Issue 8 wording was not independently confirmed; this is a primary-source-access gap, not evidence that Issue 8 changed the rule. [C1]

**Inference — Field count is insufficient dialect detection.** A five-field expression might use non-POSIX extensions; a six-field expression need not mean Quartz. Explicit dialect naming avoids silently shifting field positions or day numbering.

### Timezone, reference instant, and DST

**Fact — Cronie offers `CRON_TZ`.** Its crontab documentation distinguishes the schedule’s timezone from the daemon-local timezone used for log timestamps. [C2]

**Fact — Cronie’s own documentation exposes a DST-policy tension.** `crontab(5)` says nonexistent local times do not match and repeated local times match twice. In contrast, `cron(8)` documents special treatment for clock changes under three hours: skipped fixed-time jobs run soon afterward and repeated fixed-time jobs are not run twice; more frequent jobs are scheduled normally. [C2][C3]

**Inference — Matching civil times and daemon execution policy must not be conflated.** The apparent discrepancy prevents a defensible blanket statement that “Cronie always skips gaps and runs folds twice.” A version-pinned interpretation of relevant source paths would be needed before promising exact emulation.

**Fact — Quartz warns about scheduling near DST changes.** Its FAQ discusses skipped or repeated times and distinguishes wall-clock schedules from fixed elapsed intervals. `CronExpression` exposes a timezone, and `getNextValidTimeAfter(Date)` searches strictly after the provided instant, returning `null` when no later match exists. [C6][C7]

**Inference — A next-run preview needs more than an expression.** It requires a named dialect, timezone, explicit reference instant, inclusion/exclusion rule, and gap/fold policy. Timezone database changes can alter future civil-time mappings; previews should not be presented as timeless facts.

### Search bounds and failure meanings

**Fact — Quartz’s API has finite year semantics.** The 2.5.1 API documents a year range of 1970–2199 and exposes `MAX_YEAR`; its next-time API can return `null`. This establishes implementation-specific bounds, not a universal cron search guarantee. [C7]

**Inference — Valid syntax is not a guarantee of a nearby occurrence.** Sparse or impossible calendar combinations require bounded search. A horizon, iteration/work budget, and result count should be explicit. “No occurrence within this search horizon,” “search budget exhausted,” and “no occurrence in the dialect’s supported date range” are different outcomes.

### Sharp open questions

- Which named dialect and version are supported? Which macros and extensions are accepted?
- Is the value only a schedule expression, or an entire crontab entry? Command text should remain separate from schedule parsing and retain command-aware quoting.
- What exactly is the DOM/DOW combination rule, including wildcard and step cases?
- Is timezone required, explicitly inherited, or supplied by the caller? Is its database version identifiable?
- Is the reference instant captured once, and is “next” strictly after it?
- Are gap/fold policies emulated from a named scheduler or defined independently?
- What horizon and work budget bound preview generation, and how are incomplete searches reported?

## 5. What this evidence does—and does not—settle

**Inference:** The common architectural distinction is **draft → interpretation → validation outcome → optional preview**, not destructive normalization. Preserve the draft and expose raw/display/typed distinctions explicitly. Rich and linear interfaces should communicate equivalent constraints and outcomes; these sources do not establish either interface’s accessibility.

The evidence identifies decisions but does not select mask editing rules, regex containment architecture, duration grammar, cron engine, or DST policy. Remaining verification would require pinned dependencies and authoritative runtime/engine behavior. No parser, platform, or assistive-technology results are claimed.

## Sources

### Masks and Unicode

- **[M1]** IMask, *Input Mask Guide*, rolling documentation; feature-version annotations included. https://imask.js.org/guide.html
- **[M2]** RobinHerbots, *Inputmask*, first-party repository/documentation, rolling branch. https://github.com/RobinHerbots/Inputmask
- **[M3]** Unicode Consortium, *UAX #29: Unicode Text Segmentation*, rolling published annex. https://unicode.org/reports/tr29/

### Dart regex and execution

- **[R1]** Dart, *RegExp class*: ECMAScript semantics, matching methods, performance warnings. https://api.dart.dev/dart-core/RegExp-class.html
- **[R2]** Dart, *RegExp constructor*: flags, Unicode behavior, syntax errors. https://api.dart.dev/dart-core/RegExp/RegExp.html
- **[R3]** Dart, *Future.timeout*. https://api.dart.dev/dart-async/Future/timeout.html
- **[R4]** Dart, *Isolate.kill*. https://api.dart.dev/dart-isolate/Isolate/kill.html
- **[R5]** Dart, *Concurrency in Dart*. https://dart.dev/language/concurrency
- **[R6]** Flutter, *compute*. https://api.flutter.dev/flutter/foundation/compute.html

### Duration

- **[D1]** Dart, *Duration class*. https://api.dart.dev/dart-core/Duration-class.html
- **[D2]** Dart, *Duration constructor*. https://api.dart.dev/dart-core/Duration/Duration.html
- **[D3]** Dart, *int class*, platform integer representations. https://api.dart.dev/dart-core/int-class.html

### Cron

- **[C1]** *crontab*, hosted reproduction of SUSv4 TC2 specification; direct Open Group retrieval unavailable. https://ktiml.mff.cuni.cz/~kucerap/unix/susv4tc2/utilities/crontab.html
- **[C2]** Cronie, *crontab(5)*, first-party `master` source. https://github.com/cronie-crond/cronie/blob/master/man/crontab.5
- **[C3]** Cronie, *cron(8)*, first-party `master` source. https://github.com/cronie-crond/cronie/blob/master/man/cron.8
- **[C4]** Quartz 2.3.0, *Tutorial Lesson 6: CronTrigger*. https://www.quartz-scheduler.org/documentation/quartz-2.3.0/tutorials/tutorial-lesson-06.html
- **[C5]** Quartz 2.2.2, *CronTrigger Tutorial*. https://www.quartz-scheduler.org/documentation/quartz-2.2.2/tutorials/crontrigger
- **[C6]** Quartz 2.4.x, *Frequently Answered Questions*. https://www.quartz-scheduler.org/documentation/quartz-2.4.x/faq.html
- **[C7]** Quartz 2.5.1 API, *CronExpression*. https://www.quartz-scheduler.org/api/2.5.x/org/quartz/CronExpression.html

---

## Addendum: selected adaptive masks and calendar-relative durations

**Scope update:** Both **fixed and adaptive masks**, and both **fixed elapsed and calendar-relative durations**, are selected requirements. The findings below supplement the report; they do not reopen those mode selections. Policy questions concern how the selected modes behave.

### 1. Adaptive masks: ambiguity, switching, and paste

#### Primary-source precedents

**Fact — IMask explicitly supports adaptive selection.** Its dynamic-mask mode accepts an array of candidate masks. The documented automatic selection chooses the mask with the largest number of fitting characters, using array order to resolve ties. A custom `dispatch` function can select the mask instead. This is a library policy, not a standard definition of adaptive masking. [A1]

**Fact — Inputmask offers a different switching precedent.** Its `keepStatic` option is intended to retain the current mask until switching becomes necessary. The first-party changelog records a change in version 5.0.7: multiple-mask configurations default to `keepStatic: true`, while other configurations default to false. This shows that switching stability is independently configurable and version-sensitive. [A2][A3]

**Fact — Formatted and unformatted input are separate API pathways.** IMask exposes setters for `value` and `unmaskedValue`, alongside dynamic dispatch and preprocessing hooks. Inputmask exposes paste preprocessing through `onBeforePaste` and separately controls retrieval through `autoUnmask`. Neither API establishes a universal rule that arbitrary pasted text can always be unambiguously classified as raw versus formatted. [A1][A2]

**Source boundary:** No source-owned general standard for adaptive input-mask selection or formatted-paste detection was identified. These first-party browser-library APIs are precedents, not TUI requirements or accessibility guarantees.

#### Implications for the selected modes

**Inference — Adaptive mode needs explicit candidate identity and ambiguity semantics.** A partial draft may fit several candidates. “Most fitting characters,” configured order, stable selection, and semantic dispatch can produce different selections. A candidate chosen for a partial draft is not necessarily evidence of user intent.

**Inference — Selection and rewriting are separate operations.** Changing the active candidate can change punctuation, slot layout, or interpretation without changing raw characters. The contract should distinguish:

1. preserved original draft;
2. selected candidate or unresolved candidate set;
3. derived raw value;
4. formatted presentation;
5. validation/completeness status.

This is a conceptual distinction, not a required implementation structure.

**Inference — Raw-versus-formatted paste cannot safely be decided by stripping all punctuation.** A character might be a literal in one candidate and meaningful data in another. Removing it could change both candidate selection and the submitted value. The existing no-silent-changes requirement applies equally to adaptive masks.

**Inference — Switching must account for editing, not just appending.** Deleting a distinguishing prefix, replacing a middle range, or pasting over a selection can reopen ambiguity. The cited web APIs do not establish terminal cursor placement or deletion behavior after such changes.

#### Sharp open questions—not mode-selection questions

- What identifies a candidate, and can the user inspect which candidate is active?
- Are ambiguous drafts represented as unresolved, provisionally selected, or selected by documented precedence?
- When can selection change: every edit, only when the current candidate becomes impossible, or at another explicit point?
- Can the user explicitly select or retain a candidate, and what happens when later input conflicts with it?
- Is paste interpreted as raw, formatted, explicitly chosen by the user, or evaluated under both interpretations?
- If both paste interpretations succeed but yield different values or candidates, how is ambiguity exposed without changing the preserved draft?
- Does changing candidates alter only presentation, or can it change raw-value interpretation? How is that distinction communicated in rich and linear interaction?
- What happens to the logical insertion position when literals appear, disappear, or move?

### 2. Calendar-relative duration: tuple first, anchored arithmetic separately

#### Source-owned standards evidence

**Fact — Calendar periods can retain components without immediately becoming elapsed seconds.** The TC39 Temporal specification defines date-duration records with years, months, weeks, and days. Temporal duration values also represent time components. These components are not universally reducible to one context-free microsecond count. Temporal is cited here as a standards-track arithmetic model, not as a Dart API or a mandated dependency. [A4]

**Fact — Anchoring determines calendar arithmetic.** Temporal’s specification separates date addition from elapsed-time addition in `AddZonedDateTime`: it applies the date portion using calendar arithmetic and then applies the time portion as elapsed time. Its documentation explains using a reference date or zoned date-time when calendar units must be interpreted, compared, totaled, or balanced. [A4][A5]

**Fact — Invalid destination dates have explicit policies.** Temporal date arithmetic supports `overflow: "constrain"` and `"reject"`. Constraining can map an invalid destination day to the last valid day of that month; rejecting raises an error. For example, adding one month to August 31 can constrain to September 30. These are named Temporal behaviors, not an automatic rule for this product. [A4][A6]

**Fact — Calendar days and elapsed hours differ across offset changes.** Temporal’s zoned-date-time documentation distinguishes calendar-day arithmetic, which aims to preserve local clock time, from elapsed-hour arithmetic. Consequently, one calendar day can span 23 or 25 elapsed hours during ordinary DST transitions, whereas 24 elapsed hours remains 24 hours. [A7]

**Fact — RFC 5545 supplies another, narrower duration model.** Section 3.3.6 permits weeks, days, hours, minutes, and seconds, but **not years or months**. It distinguishes nominal week/day durations from accurate hour/minute/second durations, says discontinuities such as DST affect nominal duration length, requires larger components to be added first, and excludes leap seconds from exact-duration computation. Thus iCalendar’s `DURATION` grammar must not be presented as a general month/year-period grammar. [A8]

#### Month-end, leap-year, and DST implications

**Inference — Store or communicate a calendar-period tuple independently of a resolved result.** A period such as “1 month, 2 days” can be meaningful before an anchor is supplied. Converting it into a Dart `Duration` prematurely loses calendar semantics. An anchored result additionally needs the anchor, calendar, timezone where applicable, and arithmetic policies.

**Inference — Do not equate months or years with fixed seconds.** “One month = 30 days” and “one year = 365 days” would be additional approximation conventions, not consequences of the cited models. They must not be silently introduced.

**Inference — Month-end and leap-day policy are observable semantics.** January 31 plus one month, or February 29 plus one year, can encounter invalid destination dates. Constrain/reject are source-backed policy examples; the product’s policy remains open. Repeated additions also need care: successive constrained additions need not equal one combined addition.

**Inference — Arithmetic order matters.** A tuple containing months and days, or days and hours, is not necessarily commutative when applied around month ends or timezone transitions. Preserving the tuple does not by itself define how to apply it.

**Inference — Calendar validity and local-time validity are separate.** A valid destination date can still contain a nonexistent or repeated local clock time. A month-end policy alone does not resolve DST gaps and folds. Fixed elapsed mode should retain its original exact-unit semantics rather than inherit calendar-mode behavior.

#### Sharp open questions—not mode-selection questions

- Which components are supported in calendar mode: years, months, weeks, days, and/or elapsed sub-day units?
- Is a period accepted without an anchor, with arithmetic preview deferred until an anchor exists?
- Which calendar is supported, and what anchor/timezone information is required for resolution?
- What is the component application order?
- What happens at month end or leap-day invalidity: constrain, reject, or another explicitly defined rule?
- What happens when the resulting local time falls in a DST gap or fold? Is this independent of cron-preview policy?
- Are repeated operations intended to preserve an original day-of-month preference, or operate on each previously resolved result?
- What sign and fractional-unit rules apply to the tuple?
- When converting an anchored calendar result to elapsed microseconds, what range and precision checks apply?
- How are the original tuple, anchor, policies, resolved endpoint, and derived elapsed span distinguished in rich and linear output?
- If the user switches between elapsed and calendar-relative modes, is the draft retained separately rather than silently converted?

### Additional sources and version qualifications

- **[A1]** IMask, *Input Mask Guide*: dynamic selection, `dispatch`, formatted/unformatted values, preprocessing. Rolling first-party documentation.  
  https://imask.js.org/guide.html
- **[A2]** RobinHerbots, *Inputmask*: `keepStatic`, paste preprocessing, value options. Rolling first-party repository/documentation.  
  https://github.com/RobinHerbots/Inputmask
- **[A3]** Inputmask, *5.x Changelog*, including version 5.0.7 behavior change.  
  https://github.com/RobinHerbots/Inputmask/blob/5.x/Changelog.md
- **[A4]** TC39, *Temporal specification*: duration records, calendar operations, `AddZonedDateTime`. Living proposal text; no particular ECMAScript edition or Dart implementation is implied.  
  https://tc39.es/proposal-temporal/
- **[A5]** TC39 Temporal, *Duration documentation*: reference-dependent interpretation.  
  https://tc39.es/proposal-temporal/docs/duration.html
- **[A6]** TC39 Temporal, *PlainDateTime documentation*: date arithmetic and overflow policies.  
  https://tc39.es/proposal-temporal/docs/plaindatetime.html
- **[A7]** TC39 Temporal, *ZonedDateTime documentation*: calendar versus elapsed arithmetic and timezone transitions.  
  https://tc39.es/proposal-temporal/docs/zoneddatetime.html
- **[A8]** IETF, **RFC 5545**, September 2009, §3.3.6, *Duration*.  
  https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.6

**Remaining evidence limits:** Adaptive-mask precedents remain browser-library analogies. Temporal and RFC 5545 provide explicit but different calendar arithmetic models; neither selects the product’s policies or proves behavior of a future Dart implementation. No parser, terminal, timezone-backend, or assistive-technology tests were performed.