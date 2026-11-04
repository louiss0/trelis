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
process. This deliberately small probe does not provide a full editor, Unicode
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
foreach ($scenario in 'submit','escape','ctrlc','eof','error') {
  powershell -NoProfile -ExecutionPolicy Bypass -File test/terminal_probe_windows.ps1 -Scenario $scenario
  Get-Content (Join-Path $env:TEMP 'prompty-probe-report.txt')
}
```

Observed in this environment (input mode:output mode:cursor size:visibility):

```text
submit PASS results=submit:ok,submit:ok state=503:7:25:1 -> 503:7:25:1
escape PASS results=cancel,cancel state=503:7:25:1 -> 503:7:25:1
ctrlc PASS results=interrupt,interrupt state=503:7:25:1 -> 503:7:25:1
eof PASS results=eof,eof state=503:7:25:1 -> 503:7:25:1
error PASS results=error,error state=503:7:25:1 -> 503:7:25:1
```

The EOF scenario injects Ctrl+Z, interpreted by this raw-console probe as an
explicit end-of-input gesture. It does **not** demonstrate an actual stream EOF
(`readByteSync` returning -1); redirected streams are rejected before setup.
The error scenario is a real input-length format error caught within the session,
not an injected OS read failure. Ctrl+C is tested as a raw input byte, not as a
process control signal. State is compared before the first and after the second
session; the harness does not observe a separate intermediate snapshot. No
forced process termination, unexpected native I/O failures, NVDA, other terminal
emulators or non-Windows platforms were qualified. These limitations must not be
mistaken for a complete component lifecycle guarantee.
