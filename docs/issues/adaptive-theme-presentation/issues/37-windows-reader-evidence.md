# 37 Collect Windows Terminal and NVDA human evidence

Status: ready-for-human

**Blocked by:** [32](32-public-api-cutover.md), [35](35-windows-native-hint.md)

**What to build:** A human must exercise the cutover and gated Windows binding with actual Windows Terminal and NVDA. Record reproducible environment, setup, utterances and observed usability, not just synthetic detection tests. Do not enable the gate here. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```text
# PROPOSED NOT IMPLEMENTED: evidence record shape
terminal: Windows Terminal
reader: NVDA
result: pass | fail | not tested
```

## Acceptance criteria

- [ ] Record human tester, date, Windows, Windows Terminal, NVDA and package versions, settings, locality and exact reproduction steps.
- [ ] With NVDA on and off, verify and record the native parameter and selected interaction, including explicit on/off and rich override; distinguish signal from usability.
- [ ] Exercise representative actual interactive prompts, choices, errors, essential and detailed help, navigation and feedback; record what NVDA announces and any failures.
- [ ] Exercise prompt plus live feedback, cleanup and a later active period; report whether re-detection and interaction remain usable.
- [ ] Record relevant native fixture and automated test commands/results alongside actual human observations, without presenting simulations as reader evidence.
- [ ] Document Narrator limitation, untested terminals/readers and remote or ambiguous locality; failed or missing evidence blocks Windows enablement.
