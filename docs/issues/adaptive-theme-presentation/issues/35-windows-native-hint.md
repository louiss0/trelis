# 35 Bind the Windows screen-reader hint behind a gate

Status: ready-for-agent

**Blocked by:** [34](34-hints-locality.md)

**What to build:** Implement and validate the documented Windows screen-reader parameter using a native binding behind a default-off rollout gate. Feed positive/negative/unknown observations into locality resolution; do not claim that the parameter detects Narrator. Do not enable the gate in this ticket. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual binding result, not a public API:
readerHint = callSucceeded ? parameterValue : unknown;
```

## Acceptance criteria

- [ ] Bind the documented Windows API with correct native types, calling convention and parameter handling; test true and false results with injected native calls.
- [ ] Test failed calls, unsupported platform, missing binding and invalid results yield unknown without blocking prompts or leaking resources.
- [ ] Test the native signal remains behind a default-off gate and cannot override explicit preferences or ambiguous locality.
- [ ] Validate the binding with a Windows native fixture where available; record commands, OS version, results and missing platform evidence.
- [ ] Document that Narrator does not set the parameter and negative is not proof no screen reader is running.
- [ ] Test observation caching during an active period and cleanup followed by fresh detection later; actual reader qualification belongs to ticket 37.
