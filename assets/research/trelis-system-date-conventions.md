# System date conventions for slash-based DateInput

Research date: **2026-11-03, host-local UTC−05:00**.  
Scope: documentation research only; **no implementation or platform tests**.

## Conclusion

DateInput should **automatically resolve the executing user’s system date preferences**, display the resulting slash-based instructions, and permit an explicit override. This is the requested behavior—not a recommendation to replace locale-sensitive entry with ISO order.

A locale identifier is not a complete description of date preferences:

- **Windows:** query the current user’s short-date pattern with user overrides enabled.
- **macOS:** inspect the effective short-date pattern of a native formatter using current user preferences; a locale identifier alone loses information.
- **Linux:** resolve the process’s date locale using `LC_ALL` → `LC_TIME` → `LANG`, then obtain its date pattern from the host’s locale implementation. Desktop settings are not a universal alternative source.
- **Dart `Platform.localeName` and `intl`:** useful for locale identifiers and locale-data fallback, but not a cross-platform API for customized system date patterns.

These conclusions follow from the platform contracts below. The precedence, failure handling, and metadata recommendations are **design proposals**, not existing OS guarantees.

## 1. Define what “follow system locale” means

The following are separate dimensions:

| Dimension | Example | Relevance |
|---|---|---|
| Display language | English UI | Does not uniquely determine date order |
| Locale identifier | `en_US` | Selects defaults; need not encode custom preferences |
| Regional date pattern | `dd.MM.yyyy` | Specifies order, widths, literals, possibly era |
| Numbering system | Latin versus Arabic-Indic digits | Affects presentation and accepted characters |
| Calendar | Gregorian, Buddhist, Japanese | Changes year/month meaning, not just order |
| Result representation | Date-only Gregorian value | Separate application contract |

Unicode explicitly distinguishes numeric/text fields, calendar year, week-based year, era, calendars, and numbering systems. In particular, `y` and `Y` are not interchangeable. Pattern interpretation must follow the source pattern language, not a generic search for three letters. [U1]

**Proposed DateInput interpretation:** preserve the effective system’s supported field order and numeric-width preferences while deliberately using `/` separators. Disclose that adaptation. A system pattern `dd.MM.yyyy` therefore yields `DD/MM/YYYY`, not dot entry.

Slash normalization is a user-required presentation adaptation; it must not silently become calendar conversion, digit normalization, or permission to discard semantically necessary fields.

## 2. Windows: regional overrides, not merely locale names

Microsoft documents `LOCALE_SSHORTDATE` as the short-date formatting string and recommends it over the older `LOCALE_IDATE` order indicator. `LOCALE_IDATE` only distinguishes month-day-year, day-month-year, and year-month-day; it cannot describe the entire pattern. [W1][W2]

`GetLocaleInfoEx` is the relevant native query mechanism. Its locale argument can identify the user-default locale. Microsoft documents that `LOCALE_NOUSEROVERRIDE` suppresses user preferences and strongly discourages its use. Consequently, obtaining locale defaults while ignoring overrides would contradict this DateInput requirement. [W3][W4]

**Recommended discovery path:**

1. Query `GetLocaleInfoEx` for `LOCALE_SSHORTDATE` using `LOCALE_NAME_USER_DEFAULT`, without `LOCALE_NOUSEROVERRIDE`.
2. Retain the exact returned pattern and source.
3. Interpret Windows date-pattern syntax before deriving slash presentation.
4. Resolve calendar and digit assumptions separately; do not infer them solely from order.

The Windows pattern includes numeric and textual month/day forms and era markers. A month-name pattern or era-bearing pattern is not automatically equivalent to a three-number Gregorian date. [W1]

**Limit:** successful discovery of `M/d/yyyy` establishes an effective short-date pattern, not every detail of the terminal’s input behavior or calendar semantics.

**Needs exact-environment probes:** custom short patterns, alternate calendar selections, service/noninteractive accounts, preference changes during execution, and API errors. These were not tested.

## 3. macOS: current preferences and effective formatter patterns

Apple documents that the current locale incorporates user customizations. `CFLocaleCopyCurrent()` provides a snapshot; applications must not assume that an already obtained locale changes when preferences change. [A1]

Apple recommends native date styles or localized templates for user-visible dates rather than imposing fixed-format strings. A formatter’s effective pattern is therefore a stronger discovery source than a locale identifier alone. [A2][A3]

**Recommended discovery path:** create a native date formatter configured for current user preferences, short date style, and no time; inspect its effective date-format pattern, calendar, and locale before deriving slash-based instructions. This is a proposed integration approach, not a tested recipe.

Do not assume that generating a pattern from a `yMd` template reproduces a user-customized **short-date style** exactly. Templates describe requested fields; the short style is the preference being investigated. Their equivalence needs probing rather than assertion. [A2][A3]

Calendar handling is particularly important. Apple’s QA1480 demonstrates that a user-selected Buddhist calendar can cause parsing year `2010` to produce Gregorian year `1467`, even when a format string has been set. Its `en_US_POSIX` recommendation concerns fixed-format interchange, **not replacing user preferences in a localized prompt**. [A4]

Reading undocumented preference keys or parsing `defaults` output is not established here as a stable public API. The stronger documented foundation is current-locale and formatter APIs.

**Needs exact-environment probes:** whether every supported macOS version reflects each custom regional short-date setting in the inspected formatter, the effects of explicitly assigning a locale, refresh behavior, alternate calendars, and terminal/process environment interactions.

## 4. Linux: process locale, desktop settings, and locale availability

For GNU libc, locale environment precedence is:

1. Nonempty `LC_ALL`.
2. Nonempty category-specific variable—`LC_TIME` for date/time.
3. Nonempty `LANG`.

This precedence matters: a process can use English messages and German dates. `LANGUAGE` is associated with message translation, not a replacement for date-category selection. [L1][L2]

The environment selects a requested locale; it does not prove that locale data is installed. Native locale activation and querying can fail. The libc locale must also actually be selected: merely inspecting a variable is not the same as asking a formatter operating in that locale. [L1][L3]

`nl_langinfo` exposes:

- `D_FMT`: date format corresponding to `%x`;
- `ERA_D_FMT`: alternate era-based date format;
- `ALT_DIGITS`: alternate symbols used in date/time formatting.

These are locale data, not CLDR pattern strings. POSIX/`strftime` directives must be interpreted in their own grammar. [L3]

**Recommended discovery path:** resolve effective `LC_TIME` selection, activate/query that locale through a suitable native boundary, and inspect its date pattern and relevant era/digit information. Avoid changing unrelated process-global locale state as an incidental side effect; the concrete mechanism requires implementation review.

On systemd systems, `/etc/locale.conf` supplies system-wide locale configuration, including `LC_TIME`; `LC_ALL` is not configured there. This is not a guarantee that a launched process has those values: session and process settings can differ. Nor is systemd universal across Linux. [L4]

**Desktop settings:** there is no universal desktop preference service established by these sources that outranks the effective process locale. A desktop-specific integration might provide additional information, but its precedence must be deliberately specified and verified for that desktop. Reading the host’s system-wide configuration instead of the process environment can produce the wrong answer for a terminal user.

**Needs exact-environment probes:** glibc versus other libc implementations, installed locale availability, `C`/`POSIX` and `C.UTF-8`, distribution/desktop launch behavior, and custom locale definitions.

## 5. Dart and `intl`: capabilities and limits

### `Platform.localeName`

The Dart API documents:

- Apple platforms: locale identifier from `CFLocaleGetIdentifier`.
- Linux and Fuchsia: the `LANG` environment variable, which may contain arbitrary values.
- Windows: the source and exact format are not specified in that API documentation. [D1]

Therefore:

- On Linux, it is insufficient for `LC_TIME` when `LC_ALL` or `LC_TIME` differs from `LANG`.
- On macOS, an identifier is not the complete current-preference object or effective formatter pattern.
- On Windows, this API alone does not promise access to the customized short-date pattern.

No exact Windows SDK implementation was confirmed in this investigation. The absence of a documented guarantee is sufficient reason not to treat it as one.

`Platform.environment` provides access to the process environment, useful for Linux precedence and diagnostic metadata. [D2]

### `intl` and CLDR

The `intl` `DateFormat` API supports locale-dependent skeletons such as `yMd`, explicit patterns, exposed patterns, and locale-data initialization. Skeletons adapt to available locale data; explicit patterns specify presentation directly. [D3]

This makes `intl` suitable for **locale-data-based resolution or an explicitly identified fallback**, not evidence that Windows custom regional settings or macOS custom short-date settings were read. The documented API does not establish such an OS-preference bridge. [D3]

Locale identifiers may include encodings, modifiers, or extensions. Blindly removing text after a separator or assuming every identifier maps losslessly into `intl` risks losing meaning. Normalization should be validated against the actual locale inventory and preserve the original identifier for diagnostics. This is a design inference from the different input contracts. [D1][D3][U1]

`DateFormat.parseStrict` rejects invalid values and extra trailing characters, but does not itself establish DateInput’s calendar, century, or Unicode-digit policy. `DateFormat` exposes native-digit controls; do not infer from that API that every Unicode decimal digit, mixed digit script, or native calendar is supported. [D3][D4]

**Version limitation:** `intl` **0.20.2** was identified as a concrete published version, but this report does not claim a source-level audit of that release’s parser or embedded CLDR revision. Pin the actual dependency and inspect its matching sources before making stronger guarantees. [D5]

## 6. Supported, ambiguous, and impossible adaptations

The following are **proposed classification rules**:

| Effective preference | Proposed handling |
|---|---|
| Numeric Gregorian day, month, year in supported order | Automatically resolve; normalize separators to `/`; show exact instructions |
| Dot, dash, spaces, or localized literals between otherwise supported fields | Normalize deliberately; disclose slash entry |
| Two-digit year | Do not silently impose a century window; disclose a four-digit-year adaptation or require a policy decision |
| Textual month/day-of-week | Do not claim exact reproduction; require a disclosed adaptation or explicit override |
| Era-dependent year | Preserve calendar/era meaning or report unsupported; never silently discard era |
| Non-Gregorian calendar | Support explicitly or require an explicit Gregorian override; do not merely relabel the year |
| Missing/repeated date fields or unrecognized pattern constructs | Treat as unresolved/unsupported |
| Invalid/unavailable locale | Report unresolved; do not reinterpret as US order |
| `C`/`POSIX` locale | Treat as an actual process locale if successfully resolved, not automatically “missing”; show its resolved presentation |

Widths, month names, literals, era, and alternative numeric forms are real pattern features in the documented grammars. [W1][L3][U1]

Ambiguous **input** is a separate problem from discovery: under a visibly resolved DMY contract, `03/04/2026` means 3 April. Do not retry it as MDY after validation failure. This is a policy recommendation to prevent silent reinterpretation.

For Unicode digits, choose and disclose an exact policy: ASCII only; ASCII plus the resolved numbering system; or a broader explicitly normalized set. Bidirectional display and mixed-script handling require dedicated tests. Locale resolution alone does not settle those decisions.

Likewise, a date-only canonical result should not accidentally become a local-midnight timestamp. Its calendar and representation must be specified independently from slash entry.

## 7. Remote, container, and account context

**“System” should mean the executing process’s effective host/user context**, not necessarily the physical keyboard owner’s desktop.

OpenSSH’s `SendEnv` and server `AcceptEnv` control whether locale variables are transmitted. Server defaults accept none; deployed configurations can differ. Thus a remote session may inherit some client locale choices, use server defaults, or contain identifiers unavailable on the server. [R1][R2]

**Inference:** containers and remote processes cannot generally recover a human’s workstation regional customizations merely from their own locale identifiers. A container may have only its configured environment and installed locale data. A service may run under another account. None of these contexts justifies guessing the user’s physical location.

Instructions and diagnostics should therefore say, for example, “Resolved from this process’s `LC_TIME`,” rather than “Your computer uses …”.

## 8. Recommended resolution and failure contract

This is a **policy proposal**, preserving automatic system defaults:

1. **Explicit caller/user override**, when supplied.
2. Otherwise, **effective native system preference** using the platform-specific sources above.
3. If only locale-data resolution is available, label it honestly as locale-derived rather than verified customized system preference.
4. If no supported resolution is possible, show the failure and ask for an explicit format override. Do not silently default to MDY, DMY, or ISO order.

Whether step 3 is permitted automatically or requires confirmation remains a product decision. Requiring confirmation is safer when native lookup failed and custom preferences may have been lost; it must not replace successful automatic resolution.

Suggested instructions:

> Date — enter **DD/MM/YYYY** using `/` and four year digits.  
> Example: **23/11/2026**. Order follows your system short-date setting; separators are normalized to `/`. Format override available.

Only include digit/calendar promises actually enforced. If Gregorian differs from the discovered calendar, require and visibly identify that explicit override.

Suggested immutable resolution metadata:

- source kind and execution platform;
- original locale identifier and effective category selection;
- original pattern and pattern grammar;
- resolved field order and widths;
- separator adaptation;
- calendar, numbering system, and era requirements, including unknown values;
- origin: system-derived, locale-data-derived, or explicit override;
- adaptation/warning information;
- snapshot time and relevant OS/runtime/library versions where obtainable.

A prompt should keep one coherent resolution snapshot while active. Preference-refresh behavior between prompts should be specified; Apple explicitly documents snapshot semantics. [A1]

## Sources

**Windows**

- [W1] Microsoft, [LOCALE_SSHORTDATE](https://learn.microsoft.com/en-us/windows/win32/intl/locale-sshortdate).
- [W2] Microsoft, [LOCALE_IDATE](https://learn.microsoft.com/en-us/windows/win32/intl/locale-idate).
- [W3] Microsoft, [GetLocaleInfoEx](https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getlocaleinfoex).
- [W4] Microsoft, [LOCALE_NOUSEROVERRIDE](https://learn.microsoft.com/en-us/windows/win32/intl/locale-nouseroverride).

**Apple**

- [A1] Apple, [CFLocaleCopyCurrent](https://developer.apple.com/documentation/corefoundation/cflocalecopycurrent%28%29?language=objc) and [Locale Concepts](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFLocales/Articles/CFLocaleConcepts.html).
- [A2] Apple, [Date Formatting](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html).
- [A3] Apple, [DateFormatter.dateFormat](https://developer.apple.com/documentation/foundation/dateformatter/dateformat).
- [A4] Apple, [QA1480: NSDateFormatter and Internet Dates](https://developer.apple.com/library/archive/qa/qa1480/_index.html).

**Linux/process locale**

- [L1] GNU libc, [Standard Environment](https://www.gnu.org/software/libc/manual/html_node/Standard-Environment.html).
- [L2] GNU gettext, [Locale Environment Variables](https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html).
- [L3] Linux man-pages, [nl_langinfo(3)](https://www.man7.org/linux/man-pages/man3/nl_langinfo.3.html).
- [L4] systemd, [locale.conf](https://www.freedesktop.org/software/systemd/man/250/locale.conf.html), version-pinned documentation **250**.

**Dart/Unicode**

- [D1] Dart, [Platform.localeName](https://api.dart.dev/dart-io/Platform/localeName.html).
- [D2] Dart, [Platform.environment](https://api.dart.dev/dart-io/Platform/environment.html).
- [D3] Dart `intl`, [DateFormat](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html), rolling API reference.
- [D4] Dart `intl`, [parseStrict](https://api.flutter.dev/flutter/package-intl_intl/DateFormat/parseStrict.html).
- [D5] Dart `intl`, [0.20.2 changelog](https://pub.dev/packages/intl/versions/0.20.2/changelog).
- [U1] Unicode, [UTS #35, Part 4: Dates](https://unicode.org/reports/tr35/tr35-dates.html), rolling specification; no particular CLDR release is asserted for the application.

**Remote sessions**

- [R1] OpenSSH, [ssh_config: SendEnv](https://man.openbsd.org/man5/ssh_config.5).
- [R2] OpenSSH, [sshd_config: AcceptEnv](https://man.openbsd.org/sshd_config).