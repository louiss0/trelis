# Investigate calendar-aware slash date entry and date-only results

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-locale-calendars
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Question

What primary-source calendar metadata, parsing/conversion mechanisms and date-only representations can support slash-based DateInput that honors the system locale's calendar, including non-Gregorian systems? Investigate ICU/CLDR and native desktop calendar support, Dart intl limitations and relevant source-backed alternatives. Cover eras/year-of-era, leap/intercalary months and month identity, variable calendar ranges, calendar versus numbering system, ASCII plus resolved native decimal digits without mixed-script numbers, ambiguity, localized field labels, strict invalid-date rejection, and a canonical result that does not invent a timezone/midnight instant. Recommend a bounded explicit support envelope and needed probes without overriding the human's non-Gregorian requirement or claiming all calendars are supported. No implementation or platform tests.

## Answer

Documentation research is complete. ICU/CLDR and native APIs establish candidate calendar metadata/conversion facilities, not a universal strict slash parser. Era/year-of-era, leap/repeated months, cyclic years, calendar variants and provider ranges can require more identity than three bare numbers. Calendar and decimal numbering system are separate; the resolved repertoire must be explicit and mixed-script numeric-token policy tested.

Dart intl's documented DateTime-based interface is not established as a non-Gregorian conversion engine. A result should preserve calendar meaning without inventing a timezone/local-midnight instant; the report proposes civil-day identity plus retained calendar fields/provenance or a calendar-qualified tuple. Those are proposals, not selected types or architectures.

The locale-calendar decision must select an explicit calendar/provider/version/range support envelope, era/leap-month grammar, strict round-trip validation and date-only result meaning. It must not silently substitute Gregorian for the human's non-Gregorian requirement. Unknown/unsupported cases need an explicit product policy. Exact-source audits and bounded calendar/digit/era-boundary probes remain required; no engine, library revision, operational calendar support or actual platform/assistive-technology tests were qualified by this report.

Follow-up questions fit [Specify locale-calendar DateInput interactions](17-locale-calendar-date-contract.md), now unblocked. No human decision was made by the research agent.

## Research context

- Supports [Specify locale-calendar DateInput interactions](17-locale-calendar-date-contract.md).
- Worker: 778b73b3-b28f-432
- Worktree: C:/Users/bvlou/projects/trelis-research-locale-calendars (created from bd5a19f)
- Research branch: research/trelis-locale-calendars
- Completed report: [Calendar-aware slash date entry and date-only results](../../../../assets/research/trelis-locale-calendars.md)
- Exact report commit: 1cf1a052e88fd507b7bc6a1852c205c1d7e29d13 on research/trelis-locale-calendars. Parent saved/committed only the complete report; the worktree is clean.
