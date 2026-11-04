# Calendar-aware slash date entry and date-only results

Research date: **2026-11-03, host-local UTC−05:00**.  
Scope: primary-source documentation research. **No implementation, platform, or assistive-technology tests were performed.** Rolling documentation and repository branches are not evidence of a pinned application dependency.

## Executive conclusion

Calendar-aware slash entry is feasible **within an explicitly bounded calendar/provider/version/range envelope**. ICU supplies calendar calculations and metadata; native Apple and Windows APIs expose additional calendar facilities. CLDR supplies localized names, patterns, numbering-system data, and calendar conventions. These are complementary capabilities—not a universal, strict slash-date parser. [U1][U2][I1][A1][W1]

Three numeric fields are not sufficient for every calendar. Era-dependent years, repeated leap months, and cyclic years can require additional identity. A calendar-aware contract must preserve those distinctions or explicitly report that the resolved configuration is unsupported. It must not quietly interpret the same digits as Gregorian.

Dart `intl` should not be treated as the non-Gregorian conversion engine: its public date-formatting interface operates on Dart `DateTime`, whose contract is an instant represented using the Gregorian calendar and UTC or local time. The documented `DateFormat` interface does not supply a selectable calendar-conversion model. [D1][D2]

**Recommendation—proposal:** retain slash-based entry, automatic effective-system resolution, prominent instructions, explicit override, and ASCII plus resolved native decimal digits. Introduce a calendar capability gate and a genuinely date-only result. Qualify non-Gregorian support incrementally; do not ship an unqualified “all calendars” claim.

This report complements the preceding system-date-conventions report. It does not repeat OS preference-source precedence.

## 1. Requirements and evidence boundaries

Ticket 17 establishes:

- Slash entry, not a calendar grid or slash-to-open shortcut.
- Automatic effective-system conventions, prominent resolved instructions, and explicit override.
- Non-Gregorian calendar semantics must be honored.
- ASCII plus the resolved locale’s decimal digits; mixed-script numbers rejected.

These are **product requirements**, not conclusions inferred from library behavior.

Important distinctions:

| Layer | What it establishes |
|---|---|
| Effective system preference | Which calendar, pattern, and numbering system the application should attempt to honor |
| CLDR metadata | Localized names, patterns, conventions, numbering-system descriptions |
| Calendar engine | Which field combinations exist and their conversion rules |
| DateInput grammar | How slash fields, eras, leap months, digits, and incomplete input are expressed |
| Result model | What a successfully entered date means independently of an instant |

**Inference:** metadata availability alone does not establish engine support; engine support alone does not establish an unambiguous slash grammar or equivalent rich/linear interactions.

## 2. Calendar fields are not interchangeable integers

### Era and year

CLDR distinguishes `G` (era), `y` (calendar year), `Y` (week-based year), `u` (extended year), `U` (cyclic year name), and `r` (related Gregorian year). Substituting one for another changes meaning. A related Gregorian year is not permission to reinterpret an entered calendar year as Gregorian. [U1]

ICU exposes separate `ERA`, `YEAR`, and `EXTENDED_YEAR` fields. Its calendar guide explains that calendars can differ in era structure and year numbering. [I1][I2]

**Consequences—proposals:**

- Resolve and retain the year model, not merely a `YYYY` label.
- For era-based entry, require an explicit era or a prominently fixed era context. Validate against era boundaries, including dates inside a transition year.
- Do not default a missing historical era to the current era silently.
- Reject unsupported cyclic-year-only patterns unless sufficient additional context identifies one year.
- Do not apply a moving two-digit-year window implicitly.

`intl` documents a moving century window for exactly two-digit years under `yy`. That behavior is unsuitable as an undisclosed product rule. [D2]

### Month identity and leap months

CLDR provides leap-month patterns and cyclic-name data. A leap month may need a marker in addition to the ordinary month name or number. [U1]

ICU exposes `IS_LEAP_MONTH` separately from `MONTH`; Apple exposes an optional `DateComponents.isLeapMonth`. These APIs demonstrate why “month = integer” is not a universally adequate identity. Their numbering conventions must not be assumed identical. [I2][A1]

Temporal’s calendar model distinguishes ordinal `month` from stable `monthCode`; leap-month codes provide additional identity. It is a useful reference model, not a claim that Dart supplies Temporal. [T1][T2]

**Proposal:** represent month identity using a provider-independent semantic code where a verified mapping exists, or retain a provider-qualified identity and leap indicator. Do not adopt `M05L`, ICU month indices, or Apple month numbers as interchangeable encodings without an explicit mapping audit.

### Ranges and calendar variants

ICU supports multiple calendar families and Islamic variants, including civil and Umm al-Qura. These must not be collapsed into one generic “Hijri” algorithm. ICU also exposes contextual field maxima; day limits can depend on the resolved year and month. [I1][I2]

ICU `GregorianCalendar` has a configurable Julian/Gregorian cutover, with a historical default. Therefore, “Gregorian” does not by itself establish proleptic Gregorian conversion behavior. [I3]

**Proposal:** a support declaration must identify:

- Exact calendar identifier and variant.
- Provider and version/data version.
- Supported date interval.
- Year/era model and month identity scheme.
- Historical cutover or proleptic rules.
- Table-backed or calculated behavior and any documented bounds.
- Behavior outside the qualified interval: explicit rejection, not an undocumented substitute algorithm.

Neither a universal 12-month limit nor a universal Gregorian year/day range is defensible.

## 3. What the available mechanisms establish

### ICU and CLDR

**Source facts:** CLDR defines calendar formatting metadata, field names, era/month names, leap-month patterns, and date-field semantics. ICU supplies calendar implementations, conversion operations, contextual ranges, and leniency controls. [U1][I1][I2]

**Proposal:** ICU is the strongest shared-engine candidate for a consistent calendar core across desktop platforms. Native APIs remain candidates where their calendar rules must match effective system behavior.

Qualification is still necessary. Record the exact ICU release, calendar type actually constructed, locale/calendar fallback behavior, and data revision. Do not infer that every identifier in CLDR is implemented by the selected ICU build.

### Apple Foundation

`DateComponents` represents calendar components and includes era, year, month, day, and leap-month information. `Calendar` provides component extraction and contextual range operations. Conversion to a Foundation `Date` crosses into an instant-based model. [A1][A2]

**Inference:** Foundation can be a conversion/metadata adapter, but a successful `Date` construction alone is not proof that the user’s exact component tuple was accepted without adjustment. A strict adapter needs verified construction semantics and component round-trip checks.

### Windows

Win32 `GetCalendarInfoEx` retrieves calendar metadata. Microsoft explicitly notes that era queries through this function return only the current era and directs callers to enumeration for other eras. Metadata retrieval must therefore not be mistaken for a complete historical-era database query. [W1][W2]

`Windows.Globalization.Calendar` exposes calendar-system selection, era/year/month/day properties, and contextual counts such as months in the current year. This is a different API surface from Win32 NLS metadata and from .NET `System.Globalization.Calendar`. [W3]

**Proposal:** evaluate these as separate adapter candidates. Do not mix their calendar IDs, month numbering, ranges, or era identifiers without a documented mapping.

### Linux

The preceding report establishes process date-locale discovery. It does **not** establish a portable native non-Gregorian conversion engine. ICU is a plausible additional dependency, not something proved present by `LC_TIME` or `nl_langinfo`.

### Dart and `intl`

Dart `DateTime` is an instant, in UTC or local time, with Gregorian fields. Its date construction/parsing facilities can normalize overflow; they are not intrinsically strict date-only validators. [D1][D3]

`intl.DateFormat` supplies localized formatting/parsing, native-digit controls, patterns, and strict parsing. Its public API does not provide a calendar object or non-Gregorian conversion selection comparable to ICU. `parseStrict` cannot manufacture missing calendar semantics. [D2][D4]

**Evidence limit:** this investigation did not establish a commit-pinned audit of every `intl` parser path, its era parsing, or its mixed-digit behavior. Those are unresolved source-validation tasks—not supported capabilities.

## 4. Slash grammar and localized instructions

### Numeric ambiguity

`03/04/2026` has no universal interpretation. Under an explicitly resolved DMY contract it denotes 3 April; under MDY it denotes March 4.

**Proposals:**

1. Resolve one grammar before editing.
2. Display calendar, field order, year/era meaning, digit sets, and a valid example prominently.
3. Parse only that grammar. Do not retry another order after validation failure.
4. Keep the resolution snapshot stable while a prompt is active.
5. Treat separator normalization as presentation adaptation, not permission to remove semantic fields.

Calendar identity should be visible where omission could mislead: for example, “Buddhist calendar; day/month/Buddhist year” rather than an unexplained `DD/MM/YYYY`.

### Era and leap-month ambiguity

**Proposed interaction options for ticket 17 to decide:**

- Keep a slash numeric body and use an explicit, persistently announced era context.
- Add an era token to the slash grammar.
- Add a documented leap-month marker or separate explicit month-identity choice.

None is established by CLDR as the required DateInput interaction. The chosen design must support the same task in rich and linear modes without silently selecting the ordinary month or current era.

If “slash-based” is ultimately constrained to **exactly three unadorned integers with no additional context**, some calendar/date combinations cannot be expressed unambiguously. That is a requirement conflict to expose, not solve through Gregorian fallback.

### Labels

CLDR supplies localized date-field names and calendar names/pattern data. [U1] These are useful inputs, but an abbreviated pattern symbol is not necessarily an adequate human instruction.

**Proposal:** use localized full field labels, explicitly qualified year/era and leap-month wording, and examples generated from the same validated calendar engine. Translation review remains necessary; no label usability or accessibility was tested here.

## 5. Digits: calendar and numbering system are independent

CLDR distinguishes decimal numeric numbering systems, with a digit repertoire, from algorithmic systems that use rules. A calendar choice does not by itself identify the digit set. [U2]

**Proposed component-specific policy implementing ticket 17:**

- Resolve one decimal numbering system and its exact ten digits.
- Accept ASCII digits and that repertoire.
- Require each numeric token to use one repertoire consistently.
- Map accepted digits to numeric values only within this component.
- Reject other decimal repertoires, lookalikes, signs, grouping marks, or compatibility forms unless separately specified.
- If the resolved numbering system is algorithmic or unresolved, disclose that the required decimal-entry adaptation is unresolved; do not pretend it supplies ten native decimal digits.

Whether different slash fields may independently use ASCII/native digits needs an explicit contract. The established requirement prohibits **mixed-script numbers**; rejecting all cross-field mixing would be an additional restriction.

Native-digit settings in a formatter do not prove this policy is enforced. Exact parser source inspection and focused validation are needed.

## 6. Strict validation is a pipeline

ICU lenient mode can normalize invalid fields; strict mode rejects out-of-range combinations. ICU also provides contextual ranges. [I2] Neither fact alone proves the complete user-input contract.

**Proposed validation sequence:**

1. Validate slash/token structure and completeness.
2. Enforce digit repertoires and explicit width/year rules.
3. Resolve calendar variant, era/year, and month identity.
4. Check the qualified support interval.
5. Construct using a non-lenient calendar path with no inherited unspecified fields.
6. Verify that conversion returns the same era, year, month identity/leap state, and day.
7. Require complete input consumption.
8. Return a date-only value only after all checks succeed.

Do not accept normalization such as day overflow, leap-month substitution, century-window expansion, or era-boundary adjustment. Editing/rollover behavior is a separate ticket-17 policy; it must not weaken final validation.

## 7. Date-only results without invented midnight

Temporal `PlainDate` explicitly models a calendar date without a time or time zone. Its distinction between calendar-facing fields and underlying ISO date identity is a useful precedent. [T1][T2]

**Proposal A: canonical civil-day identity plus retained calendar semantics**

Return:

- Proleptic-Gregorian ISO date tuple or defined integer civil-day index.
- Exact input calendar identifier/variant.
- Validated era/year/month identity/day.
- Provider/version and conversion-policy provenance where reproducibility matters.

The ISO tuple is a **canonical encoding of the converted day**, not a claim that the user entered Gregorian fields. Specify the index epoch, calendar rules, and supported range if an integer is used.

**Proposal B: calendar-qualified date**

Return an immutable calendar-qualified field tuple, with conversion supplied by a qualified provider. This preserves calendar intent but requires explicit rules for equality, ordering, persistence, and future provider changes.

**Recommendation:** use A when the application needs cross-calendar ordering and interchange; retain sufficient B-style information to preserve the entered meaning. Resolve this at the domain boundary.

Neither representation requires a local-midnight timestamp. Native/ICU adapters may internally use instant-based operations, but their conversion anchor and zone must be explicit, isolated, and verified. Serializing midnight UTC is still inventing a time; it should not become the public date-only result.

## 8. Proposed support envelope and qualification gates

**No calendar is implementation-qualified by this documentation-only report.**

Recommended staged envelope:

| Candidate | Qualification condition |
|---|---|
| Proleptic Gregorian | Explicit year bounds and proleptic rules |
| Buddhist | Verified year/era mapping and bounded conversion |
| Japanese | Explicit era semantics and exact transition-date validation |
| Selected Islamic variant | Exact algorithm/variant and supported interval |
| Hebrew, Chinese, other intercalary calendars | Verified stable month identity plus expressible leap-month grammar |
| Unknown/unsupported configuration | Explain limitation; offer explicit override; never auto-convert the entry contract |

The initial envelope must include qualified non-Gregorian operation to satisfy the requirement; “Gregorian only” is not an equivalent implementation.

### Exact-source validation before a support claim

Pin and inspect:

- Application Dart/`intl` versions and matching parser sources.
- Chosen ICU/native API versions and actual calendar construction/fallback paths.
- Calendar algorithms, cutovers, table bounds, and era data.
- Numbering-system repertoire data and digit parser behavior.
- Month identity mappings and complete-input/strictness behavior.

### Subsequent prototype questions—not tests performed here

A narrowly scoped prototype should demonstrate:

- Era transition dates and year-of-era boundaries.
- Ordinary versus repeated leap months and leap-year changes.
- Invalid dates rejected rather than normalized.
- Agreement between entered fields, canonical day, and round-trip fields.
- Explicit out-of-range and unknown-calendar failures.
- Accepted ASCII/native digits and rejected mixed-script tokens.
- Reproducible output without local-midnight assumptions.

Published reference vectors and an independently implemented calendar source would strengthen these checks. Provider disagreement should be investigated, not resolved by majority vote.

## Sources

- **[U1]** Unicode, [UTS #35, Part 4: Dates](https://unicode.org/reports/tr35/tr35-dates.html): calendar fields, patterns, eras, cyclic years, month patterns, localized field metadata.
- **[U2]** Unicode, [UTS #35, Part 3: Numbers](https://unicode.org/reports/tr35/tr35-numbers.html): numeric/algorithmic numbering systems and digit repertoires.
- **[I1]** ICU, [Calendar Services](https://unicode-org.github.io/icu/userguide/datetime/calendar/): calendar implementations and calendar model.
- **[I2]** ICU, [Calendar API](https://unicode-org.github.io/icu-docs/apidoc/released/icu4j/com/ibm/icu/util/Calendar.html): fields, leniency, contextual ranges. Rolling released reference.
- **[I3]** ICU, [GregorianCalendar API](https://unicode-org.github.io/icu-docs/apidoc/released/icu4j/com/ibm/icu/util/GregorianCalendar.html): historical cutover configuration.
- **[A1]** Apple, [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents), including [isLeapMonth](https://developer.apple.com/documentation/foundation/datecomponents/isleapmonth).
- **[A2]** Apple, [Calendar](https://developer.apple.com/documentation/foundation/calendar): component and range/conversion APIs.
- **[W1]** Microsoft, [GetCalendarInfoEx](https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getcalendarinfoex).
- **[W2]** Microsoft, [Calendar Type Information](https://learn.microsoft.com/en-us/windows/win32/intl/calendar-type-information).
- **[W3]** Microsoft, [Windows.Globalization.Calendar](https://learn.microsoft.com/en-us/uwp/api/windows.globalization.calendar).
- **[D1]** Dart, [DateTime](https://api.dart.dev/dart-core/DateTime-class.html).
- **[D2]** Dart `intl`, [DateFormat](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html).
- **[D3]** Dart, [DateTime.parse](https://api.dart.dev/dart-core/DateTime/parse.html): overflow interpretation.
- **[D4]** Dart `intl`, [parseStrict](https://pub.dev/documentation/intl/latest/intl/DateFormat/parseStrict.html).
- **[T1]** TC39 Temporal, [PlainDate documentation](https://tc39.es/proposal-temporal/docs/plaindate.html).
- **[T2]** TC39 Temporal, [Calendar documentation](https://tc39.es/proposal-temporal/docs/calendars.html).

**Remaining uncertainty:** no pinned provider/source audit, complete cross-calendar mapping, or executable prototype was completed. Exact dependency sources plus bounded conversion/grammar prototypes would settle these questions; documentation alone does not establish operational calendar support.