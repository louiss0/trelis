# 35 Bind the Windows screen-reader hint behind a gate

Status: resolved

**Blocked by:** [34](34-hints-locality.md)

**What to build:** Implement and validate the documented Windows screen-reader parameter using a native binding behind a default-off rollout gate. Feed positive/negative/unknown observations into locality resolution; do not claim that the parameter detects Narrator. Do not enable the gate in this ticket. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual binding result, not a public API:
readerHint = callSucceeded ? parameterValue : unknown;
```

## Comments

Added internal `lib/src/windows_reader_hint.dart`: `SystemParametersInfoW` with
`SPI_GETSCREENREADER` (0x004F), 32-bit `UINT` arguments, a 32-bit BOOL output
cell and an `Int32` BOOL return. Win64 is the only ABI where this SDK's FFI
calling convention matches WinAPI; Windows IA32 stdcall is not expressible here
and is reported as a missing binding. The probe is default-off and injects the
native call, allocator, platform check and binding lookup. Successful true and
false results become positive and negative observations; failed, missing,
unsupported, throwing, allocation-failing and invalid results are unknown. The
cell is initialized and freed in `finally`. `NativeHintObservations` and
`ThemeSession` still own locality, explicit-precedence and once-per-period
collection; nothing was added to the public barrel.

The binding documents that Narrator does not set this parameter, that negative
is not proof no reader is running, and that positive says nothing about which
terminal is being read. The gate was not enabled by default and no screen-reader
qualification is claimed.

Validation on this branch after merging `integration/adaptive-theme-presentation`
(already up to date, no conflicts):

- `dart test test/windows_reader_hint_test.dart -r compact` — 5 passed.
- `dart test test/hint_observations_session_test.dart test/windows_reader_hint_test.dart -r compact` — 13 passed.
- `dart test -r compact` — 4936 passed.
- `dart format --output=none --set-exit-if-changed .` — exit 0, 242 files unchanged.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files, no legacy local tracker.

Native fixture on Windows 11 Home 10.0.26200.0, checked with
`[System.Environment]::OSVersion.VersionString` and `Get-CimInstance
Win32_OperatingSystem`: `dart run tool/windows_reader_fixture.dart` with Dart
3.13.2 / windows_x64 printed `Binding: available`, fixture-only gate enabled,
and `Observation: ScreenReaderObservation.negative` (a successful call reporting
the parameter unset). Injected true/false, failure, invalid-value,
missing-binding and unsupported-path cases were also exercised on this host.

Gaps: no actual NVDA, Narrator, Windows Terminal, RDP, SSH, tmux, container or
multi-viewer session was available, so no real positive native signal, spoken
output or locality behavior was observed. Windows IA32 stdcall and other Windows
ABIs were not validated. Synthetic tests and this fixture do not qualify
accessibility; tickets 37/39 and the release gate remain open.

## Acceptance criteria

- [x] Bind the documented Windows API with correct native types, calling convention and parameter handling; test true and false results with injected native calls.
- [x] Test failed calls, unsupported platform, missing binding and invalid results yield unknown without blocking prompts or leaking resources.
- [x] Test the native signal remains behind a default-off gate and cannot override explicit preferences or ambiguous locality.
- [x] Validate the binding with a Windows native fixture where available; record commands, OS version, results and missing platform evidence.
- [x] Document that Narrator does not set the parameter and negative is not proof no screen reader is running.
- [x] Test observation caching during an active period and cleanup followed by fresh detection later; actual reader qualification belongs to ticket 37.
