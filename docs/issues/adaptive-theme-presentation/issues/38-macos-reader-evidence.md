# 38 Collect macOS VoiceOver human evidence

Status: ready-for-human

**Blocked by:** [32](32-public-api-cutover.md), [36](36-macos-native-hint.md)

**What to build:** A human must exercise the cutover and gated macOS VoiceOver binding with an actual macOS terminal and VoiceOver. Capture reproducible observed speech and usability, not just injected tests. Do not enable the gate here. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```text
# PROPOSED NOT IMPLEMENTED: evidence record shape
platform: macOS terminal
reader: VoiceOver
result: pass | fail | not tested
```

## Acceptance criteria

- [ ] Record human tester, date, macOS, terminal, VoiceOver and package versions, settings, locality and reproduction steps.
- [ ] With VoiceOver on and off, verify and record the native state and selected interaction, including explicit on/off and rich override; distinguish signal from usability.
- [ ] Exercise representative actual interactive prompts, choices, errors, essential and detailed help, navigation and feedback; record spoken output and failures.
- [ ] Exercise prompt plus live feedback, cleanup and a later active period; report whether re-detection and interaction remain usable.
- [ ] Record native fixture and automated test commands/results alongside human observations; simulations do not establish reader usability.
- [ ] List untested terminals, readers and remote or ambiguous sessions; failed or missing evidence blocks macOS enablement.
