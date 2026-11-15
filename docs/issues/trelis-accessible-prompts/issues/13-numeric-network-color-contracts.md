# Specify numeric, network and color input contracts

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 05, 18
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. These six contracts define accepted value categories, local validation and rich/linear behavior. They do not select public Dart APIs, parser libraries, backend revisions or certify support.

### Shared interaction and evidence

- Follow the resolved editor, literal-command, paste, default-capability, validation and lifecycle contracts.
- State required/optional status and active format/constraints. Optional empty input means no value, not numeric zero, transparent black, a default or cancellation.
- Enter validates/submits the current candidate. Invalid or unsupported candidates retain their drafts with actionable textual guidance. Identified paste is data, not replayed commands.
- Parsing, interpreted value, canonical preview and original draft are distinct. No silent component transformation beyond the explicit interpretation policies below.
- Local checks only by default. External checks require explicit caller policy, visible pending/error state and bounded/cancellable behavior; syntax is not availability, reachability, deliverability or ownership.
- Every essential operation and interpretation is available as text in rich and linear modes; swatches/highlights are supplementary.
- [Research numeric and network/color value grammar boundaries](18-typed-value-standards.md) contains fixed standards references, source limitations and effective-system numeric findings. No parser/platform tests were performed by that research.
- Exact dependency/source conformance and [whole-library Windows Terminal/NVDA qualification](11-verification-matrix.md) remain future implementation gates.

### NumberInput: numeric category and precision

- Integer by default; explicit decimal mode. Finite base-10 values only initially.
- Exclude hexadecimal, scientific/exponent notation, NaN, infinity, currency and percent notation.
- Integer mode rejects decimal syntax such as 1.0 rather than accepting it only because its mathematical value is integral.
- Decimal input must be complete under the advertised grammar; intermediate/incomplete forms remain editable and cannot be submitted as successful values.
- Use exact decimal interpretation for bounds, declared precision and adjustment. Do not silently lose precision or round to fit a binary representation.
- Reject values exceeding declared representational/precision limits. State those limits separately from grapheme/byte/resource limits. No particular Dart numeric type is selected.
- Retain spelling for editing; grouping or scale in the draft is not permission to change the numerical meaning.

### NumberInput: effective system conventions

- Automatically resolve effective noncurrency numeric conventions, not merely a language/locale identifier or stock formatter defaults.
- Honor supported effective separators, grouping, digit repertoire and sign/negative pattern; show concrete instructions/examples and override state before editing.
- Windows user overrides, macOS current effective preferences and Linux numeric-category precedence require the platform-specific investigation recorded in the research. Currency settings do not define this component.
- Accept ungrouped values or values grouped exactly according to the active pattern. Reject malformed grouping and mixed separators rather than deleting them indiscriminately.
- Similar whitespace characters are not interchangeable unless explicitly included by the declared convention.
- Accept ASCII plus the resolved native decimal-digit repertoire, consistently within each number. Reject mixed-script numbers and unsupported digit systems; do not infer a ten-digit repertoire from an algorithmic numbering system.
- Honor the supported resolved noncurrency sign/negative pattern with strict, advertised positive/negative forms. Do not silently replace it with leading ASCII signs or combine incompatible patterns.
- Interpret only the active convention. Do not retry an ambiguous value under another locale after validation fails.
- Keep one coherent convention snapshot during the prompt. Do not reinterpret a draft when system preferences change automatically.
- If effective conventions cannot be resolved safely, explain the limitation and require an explicit supported override before ambiguous editing. Do not silently choose ASCII/US conventions. A successfully resolved C/POSIX convention is not automatically missing.
- Override is an explicitly chosen/declared entry convention, not an undisclosed normalization of existing text.
- Optional increment/decrement actions are explicitly configured/labeled, preserve invalid drafts and never wrap past bounds. Adjustment follows exact decimal semantics and advertised increments rather than inventing a value.

### PortInput

- ASCII decimal digits, independent of localized NumberInput syntax. No signs, grouping, fractions, exponents or shell/service-name interpretation.
- Default range 1–65535. Zero is explicit opt-in with clearly explained caller-defined automatic-allocation/bind-request meaning.
- Zero is not an ordinary service/destination port by implication.
- Validate the numeric range and retain invalid text. No silent clamping.
- Do not bind a socket, reserve/probe a port or claim availability. Any explicit external check must identify its address/transport/context and cannot promise a later bind succeeds.

### IPAddressInput

- Default: one numeric IPv4 or IPv6 address. No hostname resolution or network checks.
- IPv4 uses strict four-decimal-octet syntax with octets 0–255, not shortened, hex/octal or ambiguous multi-digit-leading-zero forms.
- Accept legitimate IPv6 forms, including valid compressed/mixed forms, without requiring canonical spelling as input.
- Standalone address entry is not an endpoint/URL field: do not silently extract ports, discard brackets or apply URL escape rules.
- Preserve accepted spelling and parsed address meaning. A canonical IPv6 display, if shown, is labeled separately rather than silently rewriting the draft.
- Private, loopback, unspecified, multicast and other suitability restrictions are explicit application policy, not a hidden reachability check.
- CIDR is explicit mode and means address-with-prefix. Validate IPv4 prefix length 0–32 or IPv6 0–128; retain host bits. Do not silently mask 192.0.2.7/24 into 192.0.2.0/24.
- Applications requiring network-aligned input may add explicit constraints; the component does not turn an address-prefix into another result category automatically.
- Scoped IPv6 is explicit mode. Preserve/label the zone separately, use documented standalone address grammar, and disclose its execution-environment meaning.
- Interface existence is an explicit external check, not syntax validation. Do not discard zones or assume an old URL-percent-encoding recipe defines standalone address entry.

### URLInput

- Accept absolute URLs/URI-IRI forms only under an explicitly allowed scheme set and strict declared scheme profiles. No relative/base guessing, missing-scheme insertion or arbitrary acceptance of every parser-recognized scheme.
- Non-web profiles do not inherit HTTP's authority/host shape. Define required structure and relevant constraints for each allowed scheme before entry.
- HTTP(S) profiles enforce their host/structure requirements. Generic Uri.parse success is not sufficient validation.
- Reject repair-dependent malformed escapes, controls and wrong structural forms rather than applying browser address-bar repair.
- Unicode/IDNA processing is an explicit part of the profile. For internationalized DNS names, use a declared versioned UTS #46 nontransitional/IDNA validation profile, not merely Punycode encoding.
- Display labeled Unicode/ASCII host interpretations where useful. DNS suitability/reachability/public-network restrictions remain explicit application policy.
- Reject all embedded userinfo initially. Credentials belong in separate appropriate inputs; errors must not replay their contents. This is not a secret-input field or permission to log credential-bearing rejected data.
- Preserve accepted spelling as the answer. Expose interpreted/IDNA/canonical forms separately, without implicitly replacing the draft or committed spelling.
- Do not decode reserved escapes, change path/query semantics, extract a URL from surrounding text or strip whitespace as an undisclosed repair.
- Any future canonical-output feature requires an explicit contract rather than being introduced by a serializer implementation.
- No network request is implied.

### EmailInput

- Accept one bare modern SMTP transport address, including quoted local parts and address literals under the declared grammar.
- Exclude display-name wrappers, header comments/folding, mailbox lists and groups. Do not silently extract an address from unsupported pasted syntax.
- Default to ASCII local parts, with validated internationalized domains supported.
- Unicode local parts require explicit SMTPUTF8 opt-in and clear downstream support disclosure. Converting a domain to an ASCII label does not make a Unicode local part ASCII.
- Preserve local-part case and meaningful quoting. Do not lowercase or normalize the whole address.
- Use the declared versioned UTS #46 nontransitional/IDNA profile for internationalized DNS domains; distinguish DNS domains from transport address literals.
- Preserve entered valid spelling; any domain/canonical interpretation is explicit information rather than a hidden rewrite.
- Enforce relevant transport octet limits separately from UI character limits. Do not substitute one arbitrary grapheme-count check for the transport grammar.
- Optional caller-configured local/domain suggestions follow separate autocomplete acceptance/submission semantics, never silently rewriting the local part or contacting a service.
- Local validity is not mailbox existence, deliverability, ownership or SMTPUTF8 capability discovery.

### ColorInput

- Initial scope is concrete sRGB hex, literal RGB/HSL functions and a declared static CSS-name set, with alpha supported by default.
- Use a declared CSS Color 4 subset/version. Support the documented modern and legacy function forms, including their unit/mixing rules rather than accepting only a function-name prefix.
- Hex forms include #RGB, #RGBA, #RRGGBB and #RRGGBBAA with alpha last. Named/static forms and transparent follow the declared CSS subset.
- Exclude contextual/system colors, currentcolor, variables, calculations, relative-color expressions and wider spaces such as Lab/OKLab/Display P3 initially.
- Reject out-of-range RGB channels, saturation/lightness or alpha rather than silently applying CSS clamping. Cyclic hue interpretation is explicit, documented and previewed.
- Alpha survives interpretation/submission and remains readable as text. Transparent black is a real value, not absent input or an opaque replacement.
- Preserve supported sRGB/alpha value precision and the validated source expression for re-editing. Do not implicitly quantize all answers to 8-bit channels.
- Label derived rounded hex or terminal swatch approximations as previews, not replacement answers. State conversion/precision limits; do not imply a terminal can display every accepted value exactly.
- Textual syntax/value/alpha and validation are sufficient without color discrimination. No-color/linear mode retains meaningful entry and feedback.
- CSS numeric/functional syntax is its own declared grammar, not automatically NumberInput's system-localized separator rules.

### Examples and conformance requirements

- Number examples must be generated for the active convention and include grouped/ungrouped, sign, decimal precision, native/ASCII and rejected mixed-pattern cases. A comma is not globally either grouping or decimal.
- Port: 65536 fails; zero fails unless explicitly enabled and labeled; a syntactically valid number never means available.
- IP: accepted address/prefix retains host bits; zones remain explicit; valid noncanonical IPv6 and rejected legacy IPv4 forms need tests.
- URL: allowed-scheme structure, malformed escapes, Unicode/ASCII domain interpretation, userinfo redaction and unchanged path/query spelling need conformance cases.
- Email: quoted local parts, literals, local-part case, internationalized domains, SMTPUTF8 gating and octet limits need positive/negative cases.
- Color: modern/legacy forms, alpha-last hex, transparent versus absence, exact source re-editing, invalid ranges and approximate swatch/hex labeling need tests.
- Exact implementation sources must be checked against these human-selected rules; a permissive parser, formatter or README cannot substitute for this contract.
## Question

For NumberInput, PortInput, IPAddressInput, URLInput, EmailInput and ColorInput, which local formats, bounds, interpretation/normalization rules and optional adjustments must the user be told about? Define empty/intermediate input, parse-versus-environment-validation boundaries, actionable textual feedback, rich and linear examples and any command extensions. Apply the resolved shared editing, grammar and accessibility contracts; distinguish syntax from availability/reachability/deliverability and do not choose Dart APIs.
