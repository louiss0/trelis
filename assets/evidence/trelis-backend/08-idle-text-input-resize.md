# Ticket 08 — idle TextInput resize evidence

- **Status:** pass for the public resize seam **and** for a reachable native observation path (see *Native idle-resize observation* below, added by the post-review fixes).
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

## Native idle-resize observation

`lib/src/native_resize.dart` supplies the observer both native transports were
missing. It reads the console the prompt paints to (`terminalColumns`/
`terminalLines` of the selected output), forwards POSIX `SIGWINCH` as a hint,
and keeps a bounded 250 ms poll where the console cannot notify — the Windows
console has no resize event a prompt can watch without consuming the input
records it also reads. Unknown, zero, negative and throwing readings are
unusable rather than fabricated geometry; the prompt still owns coalescing and
teardown.

Executed on Windows with the real console:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario resize -Report $env:TEMP/prompty-ticket-08-resize.txt
```

Result:

```text
text input resize PASS result=012345678901234567890123456789012345678901234567890123456789 state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1
```

The scenario shrinks the console buffer from 120x30 to 40x20 through Win32
`SetConsoleWindowInfo`/`SetConsoleScreenBufferSize` and injects **no key**: the
draft row must become `> <…` (windowed inside 40 cells) before the harness sends
Enter. The POSIX PTY scenario `resize` proves the same path in CI by resizing the
pseudo-terminal to 30 columns and waiting for the overflow marker.

`test/native_resize_test.dart` covers the deterministic parts: the observer's
unusable readings, the console read for attached/redirected/failing output, the
bounded cadence, the platform notification source, and a poll-only idle reflow
at the public prompt seam.

Terminal attribute restoration (`503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`) is
**B-FAIL** evidence, not resize evidence: it shows the acquired console state
returned, and it appears in this report only because the same probe run prints
it.
