# 42 Assess the interaction API release gate

Status: ready-for-human

**Blocked by:** [32](32-public-api-cutover.md), [34](34-hints-locality.md), [39](39-enable-windows-hint.md), [40](40-enable-macos-hint.md)

**What to build:** A human assesses the actual full interaction and accessibility baseline across all interactive prompt families and theme-owned feedback. Ticket 32 incorporates 10-31; platform enablement transitively requires binding and human checks 35-38. Automated or simulated reader output cannot replace actual screen-reader testing, including Windows Terminal + NVDA. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```text
# PROPOSED NOT IMPLEMENTED: release assessment
interactive_families: all assessed with actual reader
windows_terminal_nvda: pass | fail | not tested
verdict: pass | fail | blocked
```

## Acceptance criteria

- [ ] Inventory every interactive family and theme-owned feedback; link automated rich/linear, state, ASCII, no-color, essential help, safety and accessibility regression results for each.
- [ ] A human tests the full interactive baseline with actual screen-reader use, including Windows Terminal + NVDA; record component coverage, steps, spoken observations, tester, environment, date and failures.
- [ ] Review actual macOS VoiceOver and Windows reader evidence and qualified native rollout; explicitly list untested platforms and Narrator detection limitations.
- [ ] Verify explicit controls, positive-only hints and conservative locality; failed, negative or unknown detection must not be presented as proof of accessibility.
- [ ] Exercise real help, navigation, error recovery, secret/key safety, paste, cancellation and feedback coexistence; verify drafts and outcomes and record failures rather than substituting simulations.
- [ ] Verify automatic last-component cleanup, later reacquisition and re-detection, callback and failure handling with recorded tests and relevant native observations.
- [ ] Record formatter, analyzer, full tests, generators/generated diffs, examples, available native fixtures, and `dart run tool/check_issue_tracker.dart`; list any unperformed checks.
- [ ] Publish a human pass/fail/blocked assessment independent of the colour gate; no stable interaction/accessibility claim until all baseline and actual reader evidence passes.
