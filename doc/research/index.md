# Trelis research reports

Research date: **2026-11-03**, host-local UTC−05:00.

These source-informed reports preceded the interaction decisions. They contain
documentation findings and proposed validation—not claims that the components,
backend, terminal environments or screen readers have passed implementation
tests.

The current scope is **38 components**: the 40 atlas specimens minus
`StepperForm` and `RegexInput`. Earlier reports may cover 39 non-form
specimens or include regex material before `RegexInput` was removed. The
[map](../../docs/issues/trelis-accessible-prompts/map.md) is the current scope and
decision index; resolved tickets hold interaction detail.

## Initial terminal and backend investigations

- [Terminal keyboard capabilities and cross-platform conflicts](trelis-keyboard.md) —
  legacy key collisions, text/IME/Unicode, paste, remote chains and candidate
  input capability tiers. Source report commit
  `7e9259aad31af82740f7f7b9b29b0ff585c04bfb` on
  `research/trelis-keyboard`.
- [Screen-reader access and nonvisual terminal interaction](trelis-screen-readers.md) —
  documented platform capabilities, output/redraw limitations, secret safety,
  candidate environments and manual task verification. Source report commit
  `23530e5affa2c4022d9f764bd9ea56cfd9d14833` on
  `research/trelis-screen-readers`.
- [Component interaction precedents and Dart TUI feasibility](trelis-component-feasibility.md) —
  component traceability, existing terminal precedents and the archived Windows
  restoration-patch evidence. Source report commit
  `8b389e4c13eac1ef1776f5082c0b150bd27f53de` on
  `research/trelis-component-feasibility`.

## Questions that emerged during interaction design

- [Editable initial defaults in linear terminal interaction](trelis-editable-defaults.md) —
  plain Dart/POSIX cooked reads do not provide actual initial-value editing;
  native and application-managed editor candidates remain to be qualified.
  Source report commit `4b54ff62dd884d055456ff5b7c2409a2ade4a6a3` on
  `research/trelis-editable-defaults`.
- [System date conventions for slash-based DateInput](trelis-system-date-conventions.md) —
  effective OS date preferences, locale categories, field order versus calendar
  meaning, and unavailable-setting boundaries. Source report commit
  `4dcba120c24854ef4404d87413a61e0f045d8369` on
  `research/trelis-system-date-conventions`.
- [Calendar-aware slash date entry and date-only results](trelis-locale-calendars.md) —
  era/leap-month identity, bounded provider/calendar support, digit systems,
  strict validation and date-only meaning. Source report commit
  `1cf1a052e88fd507b7bc6a1852c205c1d7e29d13` on
  `research/trelis-locale-calendars`.
- [Typed-value grammar and interpretation boundaries, with numeric supplement](trelis-typed-value-standards.md) —
  effective system numeric conventions, strict parser boundaries and distinct
  IP/URL/email/color semantics. Source report commit
  `a687dbd2b499b945fe752f92a5c8bbfd9c291a06` on
  `research/trelis-typed-value-standards`.
- [Evidence for masks, durations and cron, with adaptive/calendar addendum](trelis-mask-pattern-duration-cron.md) —
  adaptive-mask ambiguity, elapsed/calendar-relative duration distinctions,
  dialect-specific cron semantics and bounded matching previews. Regex material
  is explicitly historical and out of scope. Source report commit
  `609eddedd1cc8fa16ea4fdbe9ec83f077068439c` on
  `research/trelis-mask-pattern-duration-cron`.

## How to use the reports

Use a report to understand the evidence behind a decision, then follow the
ticket link for its current contract. Do not use a research recommendation as a
human-approved design without its resolved decision ticket.

Before implementation claims, pin and inspect actual dependency/provider
sources and execute the early feasibility probes and qualification gates in
[the handoff summary](../trelis-interaction-handoff.md). Documentation research
does not substitute for those tasks.
