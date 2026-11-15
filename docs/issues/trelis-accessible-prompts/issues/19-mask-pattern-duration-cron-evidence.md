# Research mask editing, regex safety, duration and cron semantics

Type: research
Labels: wayfinder:research
Status: resolved
Assignee: research-mask-pattern-duration-cron
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Question

What primary-source evidence should inform MaskedInput, RegexInput, DurationInput and CronInput contracts? Investigate actual mask-editing precedents and distinction from secrets; Dart RegExp dialect/flags/Unicode/complexity and genuinely enforceable execution limits versus a superficial Future timeout; fixed elapsed durations versus calendar periods and exact supported precision; named cron dialects, day-of-month/day-of-week combination, timezone/reference-clock/DST gaps/overlaps and bounded next-run search. Cite source-owned docs/specs, distinguish GUI/web analogies from terminal facts, and surface product decisions without choosing them. No implementation or tests.

## Answer

Documentation investigation is complete. Adaptive-mask precedents expose raw/formatted/typed values and competing selection/paste policies, not one standardized behavior or terminal accessibility guarantee. Calendar periods retain components and are not interchangeable with fixed microseconds; anchored application needs explicit calendar, ordering, overflow and DST choices. Unix/Cronie/Quartz differ in grammar/day rules and scheduling behavior; a matching civil-time model must not be advertised as exact daemon emulation without version-specific evidence. Bounded preview outcomes must distinguish no match, horizon and exhausted work budget.

The report includes source/version limits: GUI mask libraries are analogies; the POSIX citation is an older hosted reproduction because the primary endpoint was not retrieved; Cronie manual pages have a documented DST-policy tension; Quartz references span documentation versions; no selected Dart backend/parser/source audit or operational tests were completed. Use named, pinned profile contracts before implementation instead of treating this as universal cron behavior.

Regex research predates its removal and is explicitly historical/out of scope; do not use it to introduce RegexInput or regex-based validation now. Product choices for the remaining three components stay in the active contract ticket. No human decision or platform/parser/assistive-technology test was performed by the researcher.

## Research context

- Supports [Specify mask, duration and cron input contracts](14-mask-pattern-duration-cron-contracts.md).
- Worker: b338845a-f074-4fa
- Worktree: C:/Users/bvlou/projects/trelis-research-mask-pattern-duration-cron (created from bd5a19f)
- Research branch: research/trelis-mask-pattern-duration-cron
- Completed report: [Evidence for masks, durations and cron, with adaptive/calendar addendum](../../../../doc/research/trelis-mask-pattern-duration-cron.md)
- Exact report commit: 609eddedd1cc8fa16ea4fdbe9ec83f077068439c on research/trelis-mask-pattern-duration-cron. Parent saved the full report/addendum with an explicit historical-regex scope note and committed only that report; worktree is clean.
