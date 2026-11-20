# 36 Bind the macOS VoiceOver hint behind a gate

Status: resolved

**Blocked by:** [34](34-hints-locality.md)

**What to build:** Implement the documented macOS VoiceOver-specific state as a native hint behind a default-off rollout gate. It is not a generic detector for every assistive technology. Do not enable the gate in this ticket. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual binding result, not a public API:
readerHint = voiceOverQuerySucceeded ? voiceOverState : unknown;
```

## Acceptance criteria

- [x] Bind the documented VoiceOver state using correct native types and lifetime handling; test positive and negative states through injected calls.
- [x] Test unavailable symbols, unsupported platforms, failed or invalid observations return unknown without blocking or resource leaks.
- [x] Test the native hint is default-off and cannot override explicit preferences or ambiguous locality.
- [x] Run a macOS native binding fixture when available and record OS, commands, results and any missing evidence.
- [x] Document that this is VoiceOver-specific, not detection of all readers; a negative result cannot veto a positive app hint.
- [x] Test one observation per active period and automatic cleanup followed by fresh observation on later reacquisition; actual VoiceOver qualification belongs to ticket 38.

## Comments

Added internal `lib/src/macos_voiceover_hint.dart`. An injected
`VoiceOverNativeBridge` supplies the Objective-C boundary: load AppKit and
libobjc, look up `NSWorkspace`, register `respondsToSelector:`,
`sharedWorkspace` and `isVoiceOverEnabled`, read the byte-sized Objective-C
`BOOL`, then pop the autorelease pool and close both library handles. Only
canonical bytes 0 and 1 are negative and positive; failed calls, missing
symbols, unsupported platforms, noncanonical bytes and cleanup failures are
unknown. The probe feeds the existing `NativeHintObservations.readerProbe`;
no public barrel symbol, prompt signature or `ThemeSession` default changed.

The gate constant remains `false`. Explicit on/off, explicit rich mode and
conservative locality still decide resolution, and a VoiceOver negative does
not veto a positive application hint. This binds only
`NSWorkspace.isVoiceOverEnabled`: it is VoiceOver-specific, not a detector for
other readers, remote output or a claim that a terminal is being read.
`ThemeSession` still caches one observation per active period; tests confirm
cleanup and a fresh observation on reacquisition. Qualification stays ticket
38, and enablement stays ticket 40.

Validation after merging `integration/adaptive-theme-presentation` (already
up to date at the start of work):

- `dart test test/macos_voiceover_hint_test.dart -r compact` — 11 passed.
- `dart test -r compact` — 4938 passed.
- `dart format --output=none --set-exit-if-changed .` — exit 0.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files,
  no legacy local tracker.

Native fixture evidence: added `test/voiceover_native_probe_app.dart`.
Host was `Windows_NT`, Dart 3.13.2 windows_x64; `dart run
test/voiceover_native_probe_app.dart` printed `VoiceOver fixture requires
macOS; found windows` and exited 2. No macOS host was available, so
`sw_vers`, macOS VoiceOver on/off observations and real terminal output were
not recorded. The fixture's `enabled: true` override is fixture-only and does
not enable the production gate. Synthetic injected calls cannot establish
native, terminal or human screen-reader evidence.

Gaps: no macOS binding execution, no VoiceOver on/off fixture result, no
real terminal or human reader evidence (38), and no enablement (40). The
Objective-C path remains unexecuted on this host.
