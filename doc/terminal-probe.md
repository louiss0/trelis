# Windows terminal lifecycle probe

This is a deliberately narrow experimental probe, not a component backend or
an accessibility qualification. It selects the in-repository Win32 console
implementation in `bin/terminal_probe.dart`, rather than treating the archived
Dart TUI prototype as a current pass. Its exact source is the git revision
containing that file. The only native binding package is pinned to `ffi` 2.2.0;
qualification below used Dart SDK 3.13.2 on Windows x64. The implementation
was inspected directly: it checks stdin and stderr independently, obtains their
standard Win32 handles, snapshots the input mode before setting raw VT input,
and restores that exact input mode in `finally`. It does not change the output
mode, cursor, or open a controlling terminal. Native mode-setting errors are not
silently ignored. The historical Dart TUI findings remain in
[the investigation](terminal-backend-ticket-01-investigation.md).

Run `dart run bin/terminal_probe.dart` in a Windows console. Stdin is the sole
input owner; stderr carries the prompt and stdout carries the outcome, so stdout
may be redirected independently. Enter submits up to five ASCII characters;
Escape cancels; Ctrl+C interrupts; Ctrl+Z ends input; a sixth printable character
produces a recoverable input error. `--twice` runs two sessions in the same
process; `--pause-between` waits for Enter with the console restored between
them. An explicit `--stream-stdin` selects a separate simple stream probe: it
reads stdin without acquiring or changing console modes, submits on LF, and
reports EOF without submitting a partial line. It is not an automatic fallback
or a qualified linear component editor. This deliberately small probe does not provide a full editor, Unicode
handling, terminal escape-sequence decoding, signal-based interruption, or
component semantics. It doesn't install an asynchronous stdin reader or open
another input handle. Input and prompt output must both be real console handles;
otherwise rich interaction fails before terminal setup, with exit code 2 and no
downgrade. The application must ensure no other reader owns stdin concurrently.

## Observed evidence

On the command host, the parent streams were redirected. The harness
`test/terminal_probe_windows.ps1` started a child with its own console, attached
only for native state inspection and `WriteConsoleInput` key injection, and
ran two sessions per scenario. From the repository root, on Windows:

```powershell
foreach ($scenario in 'submit','escape','ctrlc','eof','error','stream-eof') {
  powershell -NoProfile -ExecutionPolicy Bypass -File test/terminal_probe_windows.ps1 -Scenario $scenario
  Get-Content (Join-Path $env:TEMP 'prompty-probe-report.txt')
}
```

Observed in this environment (input mode:output mode:cursor size:visibility):

```text
submit PASS results=submit:ok,submit:ok state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1
escape PASS results=cancel,cancel state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1
ctrlc PASS results=interrupt,interrupt state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1
eof PASS results=eof,eof state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1
error PASS results=error,error state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1
stream-eof PASS result=eof state=503:7:25:1 -> 503:7:25:1
```

The `eof` scenario injects Ctrl+Z, interpreted by the raw-console probe as an
explicit end-of-input gesture. `stream-eof` instead starts a child attached to a
real console with stderr inherited, sends a partial line through an explicitly
selected stdin pipe, and closes the pipe. The resulting `eof` is an actual
`readByteSync` return of -1; the partial line is not submitted. The harness
compares the child console's native state before and after this stream session.
This stream arrangement never enters raw mode, so it does **not** prove raw-mode
restoration after a real console input handle reaches EOF. Rich mode rejects
redirected stdin before setup.

For each repeated raw-console scenario, the harness snapshots native state
before the first session, at the explicit pause between sessions, and after the
second. The error scenario is a real input-length format error caught within the
session, not an injected OS read failure. Ctrl+C is tested as a raw input byte,
not as a process control signal. No forced process termination, unexpected
native I/O failures, NVDA, other terminal emulators or non-Windows platforms
were qualified. These limitations must not be mistaken for a complete component
lifecycle guarantee.
