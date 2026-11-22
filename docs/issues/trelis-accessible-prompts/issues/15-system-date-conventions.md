# Investigate system date conventions across desktop platforms

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-system-date-conventions
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Question

How can a Dart terminal prompt discover the user's actual system date conventions on Windows, macOS and Linux without confusing display language, locale identifiers and customized regional date preferences? DateInput must remain slash-based, automatically follow system locale by default, show the resolved order/format and allow explicit override. Investigate primary OS/Dart/CLDR/intl sources, source precedence, remote/container/SSH environments, Unicode digits and calendar/era complications, available immutable metadata and failure/unknown cases. Distinguish ordering/presentation from calendar semantics, parsing and canonical result representation. Identify what can be documented and what needs exact-environment probes; do not implement or claim tests.

## Answer

Primary-source documentation investigation is complete. System date conventions are richer than a locale identifier. Windows short-date preference APIs can honor user overrides; macOS current-locale/native date formatters expose preference context with snapshot caveats; Linux effective LC_TIME follows LC_ALL, LC_TIME and LANG precedence and requires actual available locale data. Dart Platform.localeName/intl alone do not establish customized regional date preferences across all three platforms.

Slash adaptation, two-digit years, textual/era fields, calendar systems, digit systems, unavailable locale data and remote execution context require explicit policy. Interpret each source pattern in its own grammar; do not silently treat locale order as Gregorian calendar conversion or retry ambiguous input in another order. The report recommends transparent source metadata, one coherent per-prompt snapshot and an explicit format override when resolution is unsupported. These recommendations are not human decisions.

The active specialized-input ticket must decide calendar/digit scope, adaptation, override precedence and unknown/unavailable behavior with the human. The verification-matrix ticket must capture exact-environment preference/locale/SSH probes. No implementation, platform tests or adopted parser/backend are claimed; version-sensitive/rolling sources need exact-source verification before support promises.

## Research context

- Spawned by [Specify specialized value and key-capture interactions](07-specialized-prompt-contracts.md).
- Worker: 94f71cee-0050-47a
- Worktree: C:/Users/bvlou/projects/trelis-research-system-date-conventions (created from bd5a19f)
- Research branch: research/trelis-system-date-conventions
- Completed report: [System date conventions for slash-based DateInput](../../../../assets/research/trelis-system-date-conventions.md)
- Exact report commit: 4dcba120c24854ef4404d87413a61e0f045d8369 on research/trelis-system-date-conventions. Parent saved/committed only the full report; research worktree is clean.
