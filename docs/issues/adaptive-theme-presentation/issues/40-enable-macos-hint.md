# 40 Enable the qualified macOS hint

Status: ready-for-agent

**Blocked by:** [38](38-macos-reader-evidence.md)

**What to build:** Enable the macOS VoiceOver-specific hint by default only after reviewing successful native binding and actual VoiceOver evidence. Preserve explicit controls, locality restrictions and unknown fallback. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual rollout decision, not a public API:
macHintEnabled = bindingVerified && humanVoiceOverEvidencePassed;
```

## Acceptance criteria

- [ ] Link and review ticket 38 evidence and underlying binding tests; missing or failed actual VoiceOver evidence blocks default enablement.
- [ ] Enable only the qualified macOS VoiceOver binding and test positive, negative, failed and unsupported observations in the default configuration.
- [ ] Test explicit on/off and explicit rich precedence and that negative hints never veto a positive application hint.
- [ ] Test SSH, multiplexer, positively identified container and failed required locality checks suppress native positives as ambiguous.
- [ ] Document VoiceOver-specific coverage, false positives and untested configurations; do not assert universal detection.
- [ ] Record test commands/results and verify automatic cleanup, later reacquisition and fresh detection across active periods.
