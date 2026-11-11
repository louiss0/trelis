# Ticket 08 — idle TextInput resize evidence

- **Status:** pass for the scripted/public resize seam; native idle-resize notification remains pending platform-specific observer wiring.
- **Implemented revision:** work based on `93aa6ec0af36d7f5ba812eb5a2d601b89458042a`.
- **Environment:** Windows 10.0.26200.0, PowerShell 5.1.26100.9818, Dart SDK 3.13.2 stable (`windows_x64`).

## Public behavior exercised

`TerminalResizeObserver` is an optional public output-adapter seam. It provides notifications, raw dimensions, and a requested fallback cadence. `TextInput` subscribes only during rich editing, bounds fallback polling to 100 ms–30 s, coalesces identical dimensions, and cancels both resources at prompt exit. Unknown, zero/negative, and failed readings retain the last valid geometry. A resize invokes only the existing repaint/current-view path, so it does not alter draft, logical caret, focus, or meaningful presentation events.

Executed:

```text
dart test test/idle_text_input_resize_test.dart --reporter expanded
```

Result: **3 tests passed**. These public `TextInput` scenarios establish an idle shrink repaint/caret clipping while retaining `abcdefgh` and caret 8, one opening event only, no fabricated geometry after identical/null/zero/throwing observations, and watcher cancellation after submission.

```text
dart test test/idle_text_input_resize_test.dart test/text_input_test.dart test/terminal_io_test.dart --reporter expanded
```

Result: **33 tests passed**.

```text
dart analyze
```

Result: **No issues found**.

```text
dart test --reporter expanded
```

Result: **679 tests passed**.

## Native repaint/caret evidence

Executed the existing public native Windows terminal probe:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario linear-cursor -Report $env:TEMP/prompty-ticket-08-native.txt
```

Result:

```text
text input linear-cursor PASS result=alphXa state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1
```

This verifies native public editing, physical caret placement, and restoration after prompt exit. It is not an idle native-resize observation: the current built-in native adapter does not expose a platform resize notification source. The new optional adapter seam makes native/platform adapters able to supply one without inventing dimensions; a real terminal resize probe is therefore still required for the broader B-RESIZE/B-PLATFORM evidence gate.
