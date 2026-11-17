# Typed-value grammar and interpretation boundaries

**Research date:** 2026-11-03 (UTC−05:00)  
**Scope:** NumberInput, PortInput, IPAddressInput, URLInput, EmailInput and ColorInput. Primary standards and source-owned API documentation only.

## Status and evidence limits

This report identifies standards-defined boundaries and unresolved product choices; it does not select an architecture, acceptance policy or implementation.

The shared contract already preserves typed drafts, prohibits silent normalization unless explicitly agreed for a component, defaults to local checks, and requires rich/linear task equivalence. Consequently, a parser’s accepted input, its returned value, its serialized representation and the user’s draft must not be treated as interchangeable.

Live searches reached RFC Editor, WHATWG, W3C and Dart documentation. RFC numbers and section links below identify fixed documents. WHATWG URL and Dart’s unversioned API pages are moving references, not evidence for a particular deployed SDK. The project’s Dart SDK, target platforms and `intl` version were not established. No parser behavior was experimentally tested. The CSS discussion uses the dated **CSS Color 4 Candidate Recommendation Draft, 13 February 2024** as a stable baseline; later drafts may extend or refine it.

**Key distinction throughout:** syntactic validity is not environmental suitability. Local parsing cannot establish port availability, address reachability, successful HTTP access or email deliverability.

## 1. NumberInput

### Standards and API facts

- Dart’s `double.parse` accepts decimal floating-point syntax, including exponent notation, an optional sign, leading/trailing whitespace, and special values `Infinity` and `NaN`. Its documented examples include `.0`, `0.`, signed exponents and signed special values. Successful parsing therefore does **not** establish “finite base-10 user input.” [`double.parse`](https://api.dart.dev/dart-core/double/parse.html)
- `num.parse` first attempts integer parsing and then floating-point parsing. It also accepts hexadecimal input such as `0xFF`. `int.parse`, without an explicit radix, recognizes the hexadecimal prefix; with a radix, it supports bases 2–36. These are documented parser contracts, not recommendations for the component’s grammar. [`num.parse`](https://api.dart.dev/dart-core/num/parse.html), [`int.parse`](https://api.dart.dev/dart-core/int/parse.html)
- Dart `double` is IEEE 754 64-bit binary floating point. Many finite decimal fractions cannot be represented exactly; decimal syntax does not imply decimal arithmetic or retained decimal scale. Dart integer representation also differs between native and JavaScript targets. [`double`](https://api.dart.dev/dart-core/double-class.html), [`int`](https://api.dart.dev/dart-core/int-class.html)
- Dart exposes `isFinite` separately from parsing. A successful parse alone does not exclude special values or establish the required precision. [`num.isFinite`](https://api.dart.dev/dart-core/num/isFinite.html)
- Core numeric parsing is not a locale-aware number-entry contract. The first-party `intl` package provides `NumberFormat` for locale-dependent formatting/parsing. Its presence does not decide which locale, separators, grouping conventions or digit forms this component should accept. [`NumberFormat`](https://pub.dev/documentation/intl/latest/intl/NumberFormat-class.html)

### Choice-relevant consequences — analysis

“Finite base-10 number” still leaves several independent decisions:

1. Does base 10 include scientific notation, or only ordinary decimal notation?
2. Are `+1`, `.5`, `1.`, whitespace and negative zero accepted?
3. Is precision measured as fractional digits, significant digits, exact decimal value, or binary representability?
4. Are grouping separators permitted, and under which explicitly identified locale?
5. Must spelling distinctions such as `1.00` versus `1` survive in the committed value as well as the draft?

Neither `double.parse` nor `num.parse` answers these product questions. A parser round trip may lose scale, spelling and precision even when parsing succeeds.

## 2. PortInput

### Standards and API facts

- Transport port numbers occupy a 16-bit space. RFC 6335 divides it into System Ports **0–1023**, User Ports **1024–49151**, and Dynamic/Private Ports **49152–65535**. Port **0 is reserved**; being numerically within the space does not make it an ordinary assignable service port. [RFC 6335 §6](https://www.rfc-editor.org/rfc/rfc6335.html#section-6)
- Port assignments concern transport protocols; a number alone does not identify a universally available service. Dynamic ports are not assigned by IANA. [RFC 6335 §§6, 8](https://www.rfc-editor.org/rfc/rfc6335.html)
- Dart’s `ServerSocket.bind(address, 0)` gives zero a separate **API instruction** meaning: request an available ephemeral port from the system. The resulting socket exposes the selected port. That is bind-request semantics, not evidence that zero is a normal remote destination port. [`ServerSocket.bind`](https://api.dart.dev/dart-io/ServerSocket/bind.html)
- Binding depends on the local address and operating environment and can fail. Dart’s bind contract also distinguishes sharing behavior. A local numeric check cannot establish that a later bind will succeed. [`ServerSocket.bind`](https://api.dart.dev/dart-io/ServerSocket/bind.html)

### Unresolved product questions

- Is the value a **remote/service port**, a **local bind request**, or a generic port number?
- Is zero forbidden, an explicitly labelled “automatic” request, or merely retained as numeric input?
- Is the textual grammar decimal digits only? Are signs, whitespace and leading zeros accepted?
- If any availability check is offered, what transport, address/interface and instant does its result describe?

**Analysis:** a probe that releases a port does not reserve it for a later operation. “Valid port number” and “available port” need distinct language; availability checks would be an explicit departure from local syntax-only validation.

## 3. IPAddressInput

### Standards and API facts

- IPv4 has 32 address bits; IPv6 has 128. RFC 3986’s IPv4-literal grammar is four decimal octets in `0…255`, excluding multi-digit leading-zero octets. This is a precise URI-host grammar, not proof that every system IP parser uses identical rules. [RFC 791 §3.1](https://www.rfc-editor.org/rfc/rfc791.html#section-3.1), [RFC 4291 §2](https://www.rfc-editor.org/rfc/rfc4291.html#section-2), [RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.2)
- IPv6 textual forms include hexadecimal fields, a single `::` compression and a mixed IPv6/IPv4 form. RFC 5952 specifies canonical output conventions such as lowercase and longest-zero-run compression, while requiring acceptance of legitimate RFC 4291 forms. Canonical output rules do not justify rejecting every noncanonical input or silently rewriting a draft. [RFC 4291 §2.2](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.2), [RFC 5952 §§4–4.3](https://www.rfc-editor.org/rfc/rfc5952.html#section-4)
- Prefix notation identifies a count of significant leading bits: IPv4 `/0…32`, IPv6 `/0…128`. An address **with a prefix length** and the **network prefix itself** are different concepts. RFC 4291 explicitly describes writing a node address and subnet prefix together. [RFC 4632 §3.1](https://www.rfc-editor.org/rfc/rfc4632.html#section-3.1), [RFC 4291 §2.3](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.3)
- Thus `192.0.2.7/24` can describe a host address with prefix length; its associated network is `192.0.2.0/24`. Replacing one with the other discards host bits. This distinction follows from the cited prefix definitions, rather than a universal rule requiring every CIDR input to reject host bits.
- Scoped IPv6 addresses may use a zone identifier, commonly `fe80::1%eth0`. Zone identifiers have local meaning; interface names and indices are not globally portable address identities. [RFC 4007 §11](https://www.rfc-editor.org/rfc/rfc4007.html#section-11)
- **RFC 9844 obsoletes RFC 6874** and withdraws its update to RFC 3986. Old advice that `%25` zone syntax is the current general URI solution is therefore insufficient. Address-entry UI and URL grammar must be considered separately. [RFC 9844](https://www.rfc-editor.org/rfc/rfc9844.html)
- Dart documents `InternetAddress.tryParse` as numeric IPv4/IPv6 parsing, returning `null` on failure; hostname resolution is a separate operation. This documentation does not establish a CIDR parser or a complete component-level zone-ID grammar. [`InternetAddress.tryParse`](https://api.dart.dev/dart-io/InternetAddress/tryParse.html)

### Unresolved product questions

- Is this an address, address-with-prefix, or network-prefix control?
- If networks are accepted, are nonzero host bits rejected, retained, or explicitly converted with user agreement?
- Are scoped addresses supported, and what environment gives their zone identifiers meaning?
- Are brackets accepted only in URL/endpoint contexts, or also in standalone entry?
- Are mapped IPv6 addresses, unspecified, loopback, multicast and private addresses syntactically accepted but separately classified?

No cited syntax rule establishes reachability, interface existence or suitability for a particular connection.

## 4. URLInput

### Standards and parser facts

- RFC 3986 defines generic URI syntax, including relative references and many schemes. A successfully parsed URI is not necessarily an absolute HTTP(S) URL. RFC 9110 separately defines HTTP and HTTPS URI syntax, including a nonempty host. [RFC 3986 §§3–4](https://www.rfc-editor.org/rfc/rfc3986.html), [RFC 9110 §§4.2.1–4.2.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.1)
- WHATWG URL is a parsing/serialization model for interoperable web behavior, not merely RFC 3986 grammar. Its parser distinguishes **validation errors** from outright failure: some nonconforming inputs still produce URL records. [WHATWG URL: validation errors](https://url.spec.whatwg.org/#validation-error), [URL parsing](https://url.spec.whatwg.org/#url-parsing)
- For special schemes including HTTP(S), WHATWG processing can treat backslashes as separators, recognize non-four-part or nondecimal IPv4 forms, remove certain input whitespace/control characters, and serialize a normalized result. These behaviors differ materially from a strict RFC-style acceptance grammar. [WHATWG URL: basic parser](https://url.spec.whatwg.org/#concept-basic-url-parser), [IPv4 parser](https://url.spec.whatwg.org/#concept-ipv4-parser)
- WHATWG domain processing uses Unicode IDNA Compatibility Processing, UTS #46. IDNA2008 and UTS #46 are related but distinct specifications; “Unicode hostname support” needs a named processing profile, not merely a Punycode encoder. [WHATWG URL: domain to ASCII](https://url.spec.whatwg.org/#concept-domain-to-ascii), [Unicode UTS #46](https://www.unicode.org/reports/tr46/), [RFC 5891](https://www.rfc-editor.org/rfc/rfc5891.html)
- Generic URI authority permits userinfo. However, RFC 9110 prohibits generating userinfo in HTTP(S) references used as message targets or field values and recommends rejecting userinfo in untrusted references. WHATWG can parse credentials despite that HTTP guidance. [RFC 3986 §3.2.1](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.1), [RFC 9110 §4.2.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-4.2.4)
- Dart `Uri.parse` accepts URI references, not just absolute HTTP(S) URLs. Its published implementation documentation explicitly notes incomplete checking of percent-encoding, IPv6 and other details. Parser success is therefore not sufficient evidence of the desired URL contract. [`Uri.parse`](https://api.dart.dev/dart-core/Uri/parse.html)
- URI normalization can affect case, escapes and dot segments. WHATWG serialization also changes spellings, including domain and default-port representation. These transformations are not necessarily faithful reproduction of the draft. [RFC 3986 §6](https://www.rfc-editor.org/rfc/rfc3986.html#section-6), [WHATWG URL serialization](https://url.spec.whatwg.org/#url-serializing)

### Unresolved product questions

- Does acceptance follow strict RFC-oriented HTTP(S) syntax, WHATWG web parsing, or a documented subset?
- Must a scheme be typed explicitly? Are fragments, credentials and explicit default ports permitted?
- How are Unicode domains displayed and committed: original spelling, Unicode form, ASCII form, or multiple labelled representations?
- Which transformations require explicit confirmation rather than silent replacement?
- Are syntactically valid local/private hosts allowed? That is separate from URL grammar and network-access policy.

## 5. EmailInput

### Standards and API facts

- RFC 5322 distinguishes `addr-spec` (`local-part@domain`) from a `mailbox`, which may be a display name plus angle-bracketed address, and from address lists/groups. “One bare address” therefore excludes otherwise valid header forms such as `Ada <ada@example.org>` and comma-separated lists. [RFC 5322 §§3.4–3.4.1](https://www.rfc-editor.org/rfc/rfc5322.html#section-3.4)
- Full RFC syntax includes quoted local parts and domain literals; RFC 5322 also has comments/folding syntax. SMTP’s transport mailbox grammar is specified separately in RFC 5321. “RFC-compliant email” is too imprecise to define a single-line product grammar. [RFC 5321 §4.1.2](https://www.rfc-editor.org/rfc/rfc5321.html#section-4.1.2), [RFC 5322 §3.4.1](https://www.rfc-editor.org/rfc/rfc5322.html#section-3.4.1)
- SMTP requires preservation of local-part case and permits case-sensitive local parts, while mailbox domains follow case-insensitive DNS rules. Lowercasing the entire address is not a universally semantics-preserving normalization. [RFC 5321 §2.3.11](https://www.rfc-editor.org/rfc/rfc5321.html#section-2.3.11)
- RFC 6531’s SMTPUTF8 extension allows internationalized mailbox syntax. Sending such addresses requires appropriate SMTPUTF8 support; DNS handling of internationalized domains requires IDNA processing. Converting a domain to an ASCII A-label does **not** convert a Unicode local part into an ASCII mailbox. [RFC 6531 §§3.2–3.3](https://www.rfc-editor.org/rfc/rfc6531.html#section-3.2)
- SMTP limits include local-part and path limits measured in **octets**, not simply displayed characters; internationalized input makes that distinction important. A single UI character-count limit is not a complete standards check. [RFC 5321 §4.5.3.1](https://www.rfc-editor.org/rfc/rfc5321.html#section-4.5.3.1), [RFC 6531 §3.3](https://www.rfc-editor.org/rfc/rfc6531.html#section-3.3)

### Unresolved product questions

- Which bare-address subset is supported: dot-atom only, quoted local parts, domain literals, comments?
- Are Unicode domains accepted? Are Unicode local parts accepted independently?
- What downstream system actually supports SMTPUTF8 and the chosen IDNA profile?
- Are surrounding whitespace or pasted display-name forms errors, or candidates for an explicitly confirmed extraction?

**Analysis:** syntax acceptance must not be described as deliverability verification. DNS results do not establish mailbox existence, and successful delivery would not by itself establish user ownership. No network or verification workflow is implied by this control.

## 6. ColorInput

### Standards facts

- CSS Color 4 defines hexadecimal sRGB forms `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`; the alpha component is last. It also defines named colors, `rgb()`/`rgba()` and `hsl()`/`hsla()`. [CSS Color 4 §§5–7](https://www.w3.org/TR/2024/CRD-css-color-4-20240213/)
- Modern functional syntax uses space-separated components and optional slash alpha; legacy comma syntax remains defined, with different mixing restrictions. Component units, percentages, hue angles and out-of-range handling are grammar-specific. “Accept CSS RGB/HSL” needs more detail than recognizing a function name. [CSS Color 4 §§4.1, 5–7](https://www.w3.org/TR/2024/CRD-css-color-4-20240213/)
- `transparent` represents transparent black; it is not an absent value. `currentcolor` depends on the element’s `color` property and is not a standalone fixed swatch. Absence, transparency and contextual color are different states. [CSS Color 4 §§4.2–4.3](https://www.w3.org/TR/2024/CRD-css-color-4-20240213/)
- CSS Color 4 is wider than RGB/HSL: it includes HWB, Lab/LCH, OKLab/OKLCH and `color()` spaces such as Display P3. Accepting all CSS colors entails color-space and gamut semantics that an sRGB-only value cannot always preserve losslessly. [CSS Color 4 §§8–10](https://www.w3.org/TR/2024/CRD-css-color-4-20240213/)
- WCAG 2.2 SC 1.4.1 requires that color not be the only visual means of conveying information or identifying an action. W3C’s explanation calls for a visible alternative; a screen-reader-only label does not alone address this criterion. [WCAG 2.2 §1.4.1](https://www.w3.org/TR/WCAG22/#use-of-color), [W3C Understanding: Use of Color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color)

### Unresolved product questions

- Is the grammar a declared hex/name/RGB/HSL subset or broader CSS Color 4?
- Are both legacy and modern function syntax, percentage alpha and angle units accepted?
- Are out-of-range components rejected or interpreted according to CSS’s specified handling?
- Are transparent, absent and contextual colors distinct supported states?
- What precision and color space survive commitment and re-editing?
- What visible textual value identifies the color, alpha and selection state without relying on a swatch?

**Analysis:** under the existing rich/linear equivalence contract, a swatch cannot be the sole usable representation. Textual entry and feedback must expose the supported value semantics—including alpha and absence—without requiring visual color discrimination. WCAG does not prescribe the project’s exact serialization.

## Decisions still requiring human agreement

The standards do not settle these six product boundaries:

| Control | Decision required |
|---|---|
| Number | Decimal grammar, locale, finite-value handling and precision/scale contract |
| Port | Destination number versus bind request; meaning of zero |
| IP address | Address versus network; CIDR host bits; scoped-address support |
| URL | RFC/WHATWG acceptance profile, credentials, IDNA and permitted normalization |
| Email | Bare-address subset and separate Unicode-domain/SMTPUTF8 support |
| Color | Supported CSS subset, alpha/absence, gamut and textual representation |

To settle parser-specific uncertainties, a later implementation task needs the **chosen SDK/package versions and platforms**, plus human-approved grammar and normalization examples. That later work can verify conformance against those decisions; parser permissiveness alone must not make the decisions.

---

## NumberInput supplement: effective system numeric conventions

**Research date:** 2026-11-03 (UTC−05:00). This supplement replaces the earlier report’s unresolved NumberInput default/notation questions; the other five controls remain unchanged.

### Confirmed human decisions

NumberInput is **integer by default**, with **explicit decimal mode**. Both modes accept **finite base-10 input only**: no exponent notation, hexadecimal, `NaN` or `Infinity`.

Numeric conventions are **automatically system-derived**, with **visible instructions and an override**. This is not an ASCII-default contract. Grouping acceptance, digit repertoire, precision and fallback behavior remain separate questions.

### 1. Windows: a locale identifier does not capture customized numeric settings

Microsoft provides `GetLocaleInfoEx` with `LOCALE_NAME_USER_DEFAULT` to retrieve the current user’s locale information. Its documentation distinguishes user-overridden information from locale defaults: `LOCALE_NOUSEROVERRIDE` bypasses the user’s customizations, and Microsoft discourages using that flag because it disables user preferences. Consequently, looking up stock formatting data for a locale name is not equivalent to retrieving the effective user settings. [Microsoft: GetLocaleInfoEx](https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getlocaleinfoex), [LOCALE_NOUSEROVERRIDE](https://learn.microsoft.com/en-us/windows/win32/intl/locale-nouseroverride)

The relevant Windows fields are distinct:

| Field | Information |
|---|---|
| `LOCALE_SDECIMAL` | Nonmonetary decimal separator |
| `LOCALE_STHOUSAND` | Nonmonetary grouping separator |
| `LOCALE_SGROUPING` | Group-size sequence |
| `LOCALE_SNEGATIVESIGN`, `LOCALE_SPOSITIVESIGN` | Sign strings |
| `LOCALE_SNATIVEDIGITS` | Native digit characters |
| `LOCALE_IDIGITSUBSTITUTION` | Digit-substitution preference |

These fields are documented in Microsoft’s [Locale Information Constants](https://learn.microsoft.com/en-us/windows/win32/intl/locale-information-constants). Currency-specific separators are separate and do not define ordinary NumberInput conventions.

Grouping is not necessarily “insert a separator every three digits”: Windows represents grouping as a sequence. Digit shapes and substitution are also separate concepts. `LOCALE_SNATIVEDIGITS` describes native digits, while `LOCALE_IDIGITSUBSTITUTION` distinguishes contextual substitution, no substitution and national digits. Neither field alone defines which typed Unicode characters an application’s parser must accept. [Microsoft: LOCALE_SGROUPING](https://learn.microsoft.com/en-us/windows/win32/intl/locale-sgrouping), [LOCALE_SNATIVE*](https://learn.microsoft.com/en-us/windows/win32/intl/locale-snative-constants), [LOCALE_IDIGITSUBSTITUTION](https://learn.microsoft.com/en-us/windows/win32/intl/locale-idigitsubstitution)

**Implication — analysis:** effective Windows conventions require more information than `en-US`, `de-DE` or another locale identifier. An input instruction generated from stock locale data could contradict the user’s customized decimal or grouping separator.

**Not established:** the exact Windows-version behavior of preference-change notifications, unusual custom separator combinations, and which native-digit settings are user-editable on every supported release. Those require a declared Windows support range and version-specific verification.

### 2. macOS: current preferences and effective formatter properties matter

Apple distinguishes a locale identifier from the current user’s **logical locale**, which incorporates preference overrides. `CFLocaleCopyCurrent` supplies the current locale, but its identifier does not necessarily encode the overrides. Reconstructing a locale from that identifier can therefore lose preference information. [Apple: CFLocaleCopyCurrent](https://developer.apple.com/documentation/corefoundation/cflocalecopycurrent()), [Working With Core Foundation Locales](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFLocales/Articles/CFLocaleWorking.html)

Foundation’s `NumberFormatter` exposes the effective decimal separator, grouping separator, grouping sizes, signs and grouping behavior. Its `locale` determines locale-sensitive behavior; `numberStyle` and explicit formatter-property settings also affect the result. These properties describe more than a locale name. [Apple: NumberFormatter](https://developer.apple.com/documentation/foundation/numberformatter), [locale](https://developer.apple.com/documentation/foundation/numberformatter/locale), [decimalSeparator](https://developer.apple.com/documentation/foundation/numberformatter/decimalseparator), [groupingSeparator](https://developer.apple.com/documentation/foundation/numberformatter/groupingseparator), [groupingSize](https://developer.apple.com/documentation/foundation/numberformatter/groupingsize), [secondaryGroupingSize](https://developer.apple.com/documentation/foundation/numberformatter/secondarygroupingsize)

Apple distinguishes `Locale.current` from `Locale.autoupdatingCurrent`, which tracks changes to user preferences. That does not by itself establish that an already-configured formatter, application instructions and an in-progress draft all update together. [Apple: Locale.current](https://developer.apple.com/documentation/foundation/locale/current), [Locale.autoupdatingCurrent](https://developer.apple.com/documentation/foundation/locale/autoupdatingcurrent)

**Implication — analysis:** the relevant evidence is the effective noncurrency formatter configuration under current preferences, not merely an identifier obtained from the operating system. A formatter’s willingness to parse a string also does not establish compliance with the chosen restricted grammar.

**Not established:** uniform behavior for every macOS custom-number setting across supported OS releases, or the precise refresh behavior of the eventual application’s formatter lifecycle. Native formatter documentation is not evidence that Dart `intl` automatically inherits these preferences.

### 3. Linux: numeric locale is category-specific

For GNU libc’s environment-based locale selection, the order for numeric conventions is:

1. Nonempty `LC_ALL`;
2. otherwise nonempty `LC_NUMERIC`;
3. otherwise `LANG`.

`LC_ALL` overrides individual categories. `LC_NUMERIC` controls nonmonetary numeric conventions; language/message settings are not a substitute. [GNU libc: Standard Environment](https://www.gnu.org/software/libc/manual/html_node/Standard-Environment.html), [Locale Categories](https://www.gnu.org/software/libc/manual/html_node/Locale-Categories.html)

There is an important qualification: a C process initially has the `"C"` locale; environment-based selection occurs when the relevant locale facilities are initialized, for example by `setlocale` with an empty locale name. Environment intent and the process’s active locale are therefore not automatically identical. [GNU libc: Setting the Locale](https://www.gnu.org/software/libc/manual/html_node/Setting-the-Locale.html)

For an active numeric locale, `localeconv` provides `decimal_point`, `thousands_sep` and `grouping`. Grouping is a sequence of group sizes with special repeat/termination semantics, not just a Boolean option. Locale selection can fail when requested locale data is unavailable. [GNU libc: General Numeric](https://www.gnu.org/software/libc/manual/html_node/General-Numeric.html), [Setting the Locale](https://www.gnu.org/software/libc/manual/html_node/Setting-the-Locale.html)

**Implication — analysis:** a Linux desktop’s display language, `LANG` alone, and the effective numeric category can differ. These sources establish GNU libc behavior, not a promise that all Linux runtimes, containers, desktops or alternative C libraries provide identical locale integration.

**Not established:** which locale source the eventual application treats as authoritative when environment variables, desktop preferences and active runtime settings disagree. The basic `localeconv` numeric fields also do not settle a Unicode input-digit policy.

### 4. Dart: `Platform.localeName` is not an effective numeric-settings API

Dart documents `Platform.localeName` as a locale **name**. On Linux and Fuchsia it derives that name from **`LANG`**; on macOS/iOS it uses `CFLocaleGetIdentifier`. Its documented result therefore does not provide Linux’s complete numeric-category precedence or macOS preference overrides. The property does not expose Windows’ customized separator/grouping/digit fields either. [Dart: Platform.localeName](https://api.dart.dev/dart-io/Platform/localeName.html)

`intl.NumberFormat` provides locale-based formatting and parsing using its locale data and symbols. The documented API does not promise automatic import of Windows per-user numeric overrides, macOS effective formatter preferences or Linux `LC_NUMERIC`. Passing an OS locale name to `NumberFormat` is consequently not documented as equivalent to following effective system numeric conventions. [Dart intl: NumberFormat](https://pub.dev/documentation/intl/latest/intl/NumberFormat-class.html)

Its parsing contract must also be separated from strict input validation:

- `NumberFormat.parse` returns a `num`; it is not an exact-decimal or retained-scale value contract.
- The source-owned parser accepts/replaces grouping separators while scanning; that is not evidence of strict validation of every grouping position.
- The inspected historical parser recognizes ASCII digits and locale digits using a locale-zero code point and offsets. That does not establish support for every Unicode decimal-digit family or arbitrary numbering system.
- A formatting option such as `turnOffGrouping` does not, by its name or formatting purpose alone, establish that grouping is rejected during parsing.

Sources: [`NumberFormat.parse`](https://pub.dev/documentation/intl/latest/intl/NumberFormat/parse.html), [`turnOffGrouping`](https://pub.dev/documentation/intl/latest/intl/NumberFormat/turnOffGrouping.html), [source-owned parser snapshot, commit `46807423027a1996ed0dfb2bff9129f29683cf5f`](https://dart.googlesource.com/intl/+/46807423027a1996ed0dfb2bff9129f29683cf5f/lib/src/intl/number_parser.dart).

**Version limitation:** that pinned parser source establishes behavior for that revision only. The project’s actual `intl` version must be inspected before attributing identical behavior to it. Neither this source inspection nor a successful `intl` parse demonstrates enforcement of the human-approved no-exponent/no-special-value grammar.

The previous precision findings still apply: Dart `double` is binary floating point, and native/JavaScript integer behavior differs. System-localized syntax does not resolve the committed value’s exactness or range. [Dart: double](https://api.dart.dev/dart-core/double-class.html), [int](https://api.dart.dev/dart-core/int-class.html)

### 5. Remaining product questions—not decisions made by this research

1. **Grouping acceptance:** Are grouped inputs accepted, or are system grouping conventions shown only where grouping is supported? If accepted, must positions exactly match the effective primary/secondary grouping pattern?
2. **Ambiguous pasted values:** Under one convention, `1,234` may denote a grouped integer; under another, a decimal fraction. Is interpretation exclusively determined by the visibly selected convention? No cited standard provides a universally safe automatic guess.
3. **Whitespace separators:** Are only the effective separator characters accepted, or also similar spaces such as ordinary space, no-break space and narrow no-break space? Treating them as equivalent would be an explicit grammar rule.
4. **Digit repertoire:** Are ASCII digits accepted alongside system-native digits? Are other Unicode decimal digits or mixed digit families accepted? Rendering substitution preferences do not answer input acceptance.
5. **Signs and integer mode:** Which sign strings are accepted? Is `1.0` rejected in integer mode as decimal syntax even though its mathematical value is integral? Is negative zero distinct?
6. **Override scope:** Does override select a locale, an explicit numeric-convention profile, or individual separators/digits? Does it persist, and how is the active override exposed in both rich and linear interaction?
7. **Unavailable settings:** What happens when effective system settings cannot be obtained, locale data is missing, or separators conflict? A visible fallback or explicit request for a convention remains a human decision; this research does **not** replace the chosen system default with an ASCII default.
8. **Preference changes mid-draft:** Are conventions frozen for an interaction or updated live? How is reinterpretation avoided if a system change occurs while a draft is present?
9. **Precision/range:** What integer bounds and decimal precision/scale are supported, independently of localized spelling?

**Contract consequence — analysis:** visible instructions must describe the **effective active convention**, including relevant separator/digit rules and override state—not just a locale label. They must remain consistent with validation in rich and linear modes. Draft preservation and the prohibition on silent normalization continue to apply.

### What would settle the remaining technical uncertainties

A declared OS/SDK/package support matrix, the intended meaning of “system” on each platform, and human-approved grouping/digit/fallback policies would permit a subsequent version-specific conformance investigation. No architecture, implementation or tests are selected or claimed here.