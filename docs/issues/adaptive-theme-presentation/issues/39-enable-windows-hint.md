# 39 Enable the qualified Windows hint

Status: ready-for-agent

**Blocked by:** [37](37-windows-reader-evidence.md)

**What to build:** Enable the Windows native hint by default only after reviewing successful binding and actual Windows Terminal + NVDA evidence. Keep explicit controls, locality restrictions and unknown fallback; do not imply Narrator detection. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual rollout decision, not a public API:
windowsHintEnabled = bindingVerified && humanNvdaEvidencePassed;
```

## Acceptance criteria

- [ ] Link and review ticket 37 evidence and underlying binding tests; missing or failed actual reader evidence blocks default enablement.
- [ ] Enable only the qualified Windows binding and test positive, negative, failed and unsupported observations in the default configuration.
- [ ] Test explicit on/off and explicit rich precedence and that negative hints never veto a positive application hint.
- [ ] Test SSH, multiplexer, RDP, container and failed required locality checks suppress native positives as ambiguous.
- [ ] Document Windows Terminal + NVDA evidence, Narrator limitation, false positives and untested configurations; do not assert universal detection.
- [ ] Record test commands/results and verify automatic cleanup, later reacquisition and fresh detection across active periods.
