# 36 Bind the macOS VoiceOver hint behind a gate

Status: ready-for-agent

**Blocked by:** [34](34-hints-locality.md)

**What to build:** Implement the documented macOS VoiceOver-specific state as a native hint behind a default-off rollout gate. It is not a generic detector for every assistive technology. Do not enable the gate in this ticket. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual binding result, not a public API:
readerHint = voiceOverQuerySucceeded ? voiceOverState : unknown;
```

## Acceptance criteria

- [ ] Bind the documented VoiceOver state using correct native types and lifetime handling; test positive and negative states through injected calls.
- [ ] Test unavailable symbols, unsupported platforms, failed or invalid observations return unknown without blocking or resource leaks.
- [ ] Test the native hint is default-off and cannot override explicit preferences or ambiguous locality.
- [ ] Run a macOS native binding fixture when available and record OS, commands, results and any missing evidence.
- [ ] Document that this is VoiceOver-specific, not detection of all readers; a negative result cannot veto a positive app hint.
- [ ] Test one observation per active period and automatic cleanup followed by fresh observation on later reacquisition; actual VoiceOver qualification belongs to ticket 38.
