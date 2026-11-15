# Research numeric and network/color value grammar boundaries

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-typed-value-standards
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Question

Which primary standards and first-party parser contracts define the important grammar/interpretation boundaries for NumberInput, PortInput, IPAddressInput, URLInput, EmailInput and ColorInput? Surface facts a human product decision needs: decimal precision/locale versus binary numeric parsing, effective system numeric preferences (human explicitly chose automatic locale), Windows user overrides/macOS formatter preferences/Linux LC_NUMERIC precedence versus Dart localeName, grouping/digits and unsupported settings; port zero/ranges versus availability; IPv4/IPv6, CIDR host bits and scoped addresses; URL versus URI, absolute HTTP(S) URLs, credentials, IDNA/Unicode and normalization; email address versus display-name/mailbox-list syntax and internationalized addresses; supported color formats/names/alpha/color spaces and no-color presentation. Cite source-owned standards/docs and distinguish strict syntax from environment/network checks, parser permissiveness and canonicalization. Do not choose final product policies, implement code or claim tests.

## Answer

Primary-source investigation is complete. General Dart numeric/URI parser success is broader than a strict product grammar and may normalize or admit unwanted forms. Decimal syntax does not imply exact decimal arithmetic. Effective numeric conventions require Windows user overrides, macOS effective current preferences or Linux numeric-category resolution, not just Platform.localeName/stock intl data. Grouping acceptance/position validation, native-digit policy and unavailable/ambiguous settings remain product decisions.

The report distinguishes reserved port zero from an explicit automatic-bind request; IP address-with-prefix from a network that discards host bits; scoped addresses from URL syntax; RFC-oriented URI syntax from WHATWG repair/serialization; one bare email from header/list grammar and SMTPUTF8/IDNA concerns; and bounded sRGB/alpha from broader/contextual CSS colors. Syntax is not availability/reachability/deliverability. Numeric supplement preserves the human's integer-default/decimal-option and automatic-system-conventions decisions.

The active numeric/network/color ticket must choose the remaining acceptance/normalization boundaries. Exact SDK/package versions and conformance examples still need implementation-stage checks. RFC references are fixed; API/living-spec references and a pinned historical intl parser must not be mistaken for audited behavior of an adopted dependency. No implementation, network probing or parser/platform/assistive-technology tests were performed.

## Research context

- Supports [Specify numeric, network and color input contracts](13-numeric-network-color-contracts.md).
- Worker: 74288ff0-4b9a-4be
- Worktree: C:/Users/bvlou/projects/trelis-research-typed-value-standards (created from bd5a19f)
- Research branch: research/trelis-typed-value-standards
- Completed report: [Typed-value grammar and interpretation boundaries, with system numeric supplement](../../../../doc/research/trelis-typed-value-standards.md)
- Exact report commit: a687dbd2b499b945fe752f92a5c8bbfd9c291a06 on research/trelis-typed-value-standards. Parent combined the complete report and numeric supplement, committed only that file, and verified the research worktree is clean.
