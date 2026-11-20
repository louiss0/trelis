# 41 Assess the independent colour API release gate

Status: ready-for-human

**Blocked by:** [32](32-public-api-cutover.md), [33](33-background-query.md)

**What to build:** A human assesses the independent colour API stability gate against the spec and actual terminal appearance. Ticket 32 incorporates all theme and component migrations 10-31. Numerical contrast is a reference target, not a guarantee for real user terminals; missing visual evidence blocks qualification. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```text
# PROPOSED NOT IMPLEMENTED: release evidence
reference_pair_ratio: 4.5:1 or greater
actual_light_terminal_review: pass | fail | not tested
actual_dark_terminal_review: pass | fail | not tested
```

## Acceptance criteria

- [ ] Review all 15 theme light/dark defaults, accent assignments and preserved terminal backgrounds; record test and generator results.
- [ ] Verify theme/app/component palette replacement and role precedence, explicit terminal-default palette, unknown dark fallback and explicit/query/hint selection.
- [ ] Verify hard non-empty `NO_COLOR`, disabled colour, output depth degradation and query disabled/timeout behavior with recorded automated results.
- [ ] Check authored normal-text known RGB foreground/reference-background pairs target at least 4.5:1; document that indexed palettes, transparency, custom colors and actual backgrounds invalidate a universal contrast guarantee.
- [ ] A human visually reviews representative actual light and dark terminals, recording terminal, OS, settings, screenshots or observations, failures and date; simulated output alone is insufficient.
- [ ] Review migration guidance and example defaults/overrides; record formatter, analyzer, tests, generator diffs, example compilation, and `dart run tool/check_issue_tracker.dart`, or explicitly identify missing checks.
- [ ] Issue a documented pass/fail decision independent of the interaction gate; do not call colour stable with unresolved failures or missing required human visual evidence.
