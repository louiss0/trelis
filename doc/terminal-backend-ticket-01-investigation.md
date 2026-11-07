# Ticket 01 backend investigation (incomplete)

This records the initial investigation, not a backend selection or a lifecycle
pass. For subsequent probe implementation and observed evidence, see
[Windows terminal lifecycle probe](terminal-probe.md).

## Source inspected

The pub.dev `dart_tui` 3.0.0 archive downloaded from
`https://pub.dev/api/archives/dart_tui-3.0.0.tar.gz`. The SHA-256 printed by
`Get-FileHash -Algorithm SHA256` was
`3612ECFDB0BD6FE1F653A8268585943C9DAF366698D1D1B6E889BA9B47B59FCB`.
`git diff --no-index --ignore-space-at-eol` of its `lib/src/program.dart`
against `8483a5a:third_party/dart_tui/lib/src/program.dart` showed the documented
move of `enableWindowsVtInput()` before the Dart stdin mode setters, plus the
encoding marker introduced by the PowerShell comparison. The archive is not
adopted by this investigation.

## Implications for the probe

Inspection of the archived `lib/src/program.dart` and
`lib/src/windows_terminal.dart` found:

- `withOutput` selects a sink, but default dimensions are read from stdout;
  raw-mode setters target process stdin even when `withInput` selects another
  stream. Input and output capabilities must therefore be checked separately,
  and supported arrangements must be deliberately constrained or corrected.
- Windows mode setup silently returns when `GetConsoleMode` fails and ignores
  the result of `SetConsoleMode`; capability failure cannot be inferred from
  this helper succeeding.
- The `Program` input listener handles input errors as interruption, but has no
  `onDone` handler to produce an EOF outcome. The documented historical patch
  alone cannot establish the requested EOF and recoverable-error semantics.
- Windows native input mode is saved before Dart changes echo and line mode by
  the archived patch. The helper uses process-global saved state; concurrent
  ownership and failure paths need explicit treatment.

These observations are source inspection, not proof that a particular new
implementation restores state. Historical prototype results are not a pass for
this ticket.

## Execution evidence and remaining work

The current command host reported `[Console]::IsInputRedirected`,
`[Console]::IsOutputRedirected`, and `[Console]::IsErrorRedirected` as `True`.
At this investigation stage no separate native-console harness or submit,
Escape, Ctrl+C, EOF, recoverable-error or repeated-session checks had been run.
Subsequent probe evidence is recorded separately. There is no NVDA qualification.

Implement and test a real probe, explicitly account for backend limitations,
then run native original/final input-mode and cursor-state comparisons for each
exit and repeated sessions. Do not treat this investigation as completion.
