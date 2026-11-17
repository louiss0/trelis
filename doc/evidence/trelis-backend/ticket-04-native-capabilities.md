# Ticket 04 — native TextInput capability and restoration evidence

- **Status:** partial pass for the Windows and deterministic public scenarios below; Linux/macOS native CI and the later backend gate remain pending.
- **Source base:** `677eb01686e52ec489ee6372534cec58659c526b` (integration tip before this ticket's changes).
- **Recorded on:** 2026-11-11.
- **Environment:** Windows, Dart SDK 3.13.2 stable (`windows_x64`), PowerShell console probe. The probe observed `TERM=dumb` when requested; otherwise it used the inherited terminal environment. No `NO_COLOR` result is claimed by this ticket.

## Public behavior checks

`dart test test/native_text_input_capabilities_test.dart test/output_profile_text_input_test.dart test/terminal_io_test.dart test/text_input_test.dart --reporter expanded`

Result: **36 tests passed**. These tests exercise the public `TextInput`/`TerminalIo` seam: automatic output with a cursor declaration but no geometry stays linear; an explicit rich profile uses only positive geometry; supplied answers remain terminal-free; input failure restores the lease; and a simultaneous prompt and restoration failure produces `TerminalRestorationException` retaining both errors. The interruption path closes the temporary screen before returning.

`dart format --output=none --set-exit-if-changed lib/src/text_input.dart lib/src/terminal_io.dart test/native_text_input_capabilities_test.dart`

Result: pass after formatting.

`dart analyze`

Result: pass with no diagnostics.

`dart test --reporter expanded`

Result: **658 tests passed**.

## Windows native console probe

Command:

```powershell
foreach ($scenario in 'repeat','interrupt','eof','dumb-auto','dumb-rich','redirected','stdout') {
  powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario $scenario -Report $env:TEMP\ticket-04-native-report.txt
}
```

All seven scenarios passed. The probe recorded its initial, active, and final native console input/output/cursor state as follows:

| Scenario | Result | Native state (before → active → after) |
| --- | --- | --- |
| repeat | `alpha,alpha` | `503:7:25:1 → 1008:7:25:1 → 503:7:25:1` |
| interrupt | `interrupt` | `503:7:25:1 → 1008:7:25:1 → 503:7:25:1` |
| eof | `eof` | `503:7:25:1 → 1008:7:25:1 → 503:7:25:1` |
| dumb-auto | `alpha` | `503:7:25:1 → 496:7:25:1 → 503:7:25:1` |
| dumb-rich | unavailable rich interaction | `503:7:25:1 → 503:7:25:1 → 503:7:25:1` |
| redirected | `alpha`; redirected stderr contained no ANSI | `503:7:25:1 → 496:7:25:1 → 503:7:25:1` |
| stdout | `alpha`; stdout transcript contained no ANSI | `503:7:25:1 → 496:7:25:1 → 503:7:25:1` |

The state tuple is the probe's input mode, output mode, cursor size, and cursor visibility. It verifies that the native state received by the application was restored for acceptance, interruption, EOF, dumb, redirected, stdout, and repeated sessions.

## Limits

This is not platform-gate evidence. It does not claim Linux/macOS PTY execution, CI artifacts, a visible GUI/NVDA accessibility result, universal terminal/font width behavior, or `NO_COLOR` coverage. The existing native probe did not inject terminal-dimension query failures; that limitation remains for later cross-platform/native evidence work.
