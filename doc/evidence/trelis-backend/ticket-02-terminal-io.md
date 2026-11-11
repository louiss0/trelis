# Ticket 02 terminal I/O seam evidence

**Status:** partial ticket evidence; not a backend-gate pass

**Recorded:** 2026-11-11T13:05:03-05:00  
**Source revision:** `1f36c344cb343370995307ee8e1f39efe3eaddcb`  
**Branch:** `ticket/backend-02-terminal-io`

This record covers the additive terminal I/O seam from ticket 02. It does not
claim the later output-profile, native-capability, session, resize, colour,
Unicode, platform-CI, or GUI acceptance requirements.

## Change under test

`TerminalIo` is a public, replaceable adapter exposing the selected input and
output, existing rich-capability observation, and a declared environment map.
Its `acquire()` result is an idempotently restored `TerminalLease`.

`TextInput.prompt(terminal: ...)` acquires this adapter only during an
interactive invocation, restores it on supported prompt completion and error
paths, and shares the existing terminal-activity guard with native invocation.
It rejects ambiguous `source`/`terminal` and `output`/`terminal` calls before
acquisition. The native no-source path and `ScriptedInput` path remain in
place. `Text.present` and the three feedback `start` APIs select a
`TerminalIo` output without acquiring prompt input.

The legacy implementation is retained intentionally. Ticket 30 is the
contract step that may retire it only after every consumer has migrated and
compatibility evidence is complete.

## Deterministic public-boundary observations

`test/terminal_io_test.dart` uses only exported `TerminalIo`, `TerminalLease`,
`TextInput`, `Text`, and `Spinner` APIs. Its recording adapter declares
`TERM`/`NO_COLOR`, injects a selected output sink, records acquire/restore, and
can throw acquisition, selected-output, or restoration failures. It observes:

| Scenario | Expected / actual result |
| --- | --- |
| Linear `TextInput` through adapter input `Ada\r` | Accepted `Ada`; selected sink contains the prompt; events were `acquire`, `restore`. |
| Constructor and feedback output selection | Construction made no adapter event; `Text` and linear `Spinner` wrote their unchanged transcript to the selected adapter sink without acquisition. |
| Adapter acquisition failure | The original injected `StateError` escaped; only `acquire` was recorded. |
| Selected output failure after acquisition | The original injected `StateError` escaped; the recorded lease was restored. |
| Restoration failure after accepted input | The injected restoration `StateError` was observable after the public prompt completed. |
| Competing selected-output owner | A `terminal:` plus legacy `output:` invocation threw `ArgumentError` before adapter acquisition. |

The focused existing public prompt/feedback suites and the 144-case component
matrix were also run, rather than treating the new adapter test as a substitute
for unchanged behavior.

## Environment

- Windows 11 25H2: `Microsoft Windows NT 10.0.26200.0`
- Dart SDK 3.13.2 stable, `windows_x64`
- Host process input, stdout and stderr redirected: `True`, `True`, `True`
- Host environment at recording: `TERM=xterm-256color`, `COLORTERM=truecolor`,
  `NO_COLOR` absent
- Deterministic adapters, rather than those host values, supplied the test
  environments. No synthetic geometry or output profile was invented.

## Executed verification

| Command | Actual result | Scope |
| --- | --- | --- |
| `dart pub get` | passed: `Got dependencies!` | dependency resolution |
| `dart format --output=none --set-exit-if-changed .` | passed: `Formatted 122 files (0 changed)` | repository formatting |
| `dart analyze` | passed: `No issues found!` | static analysis |
| `dart test test/terminal_io_test.dart test/text_input_test.dart test/feedback_test.dart --reporter expanded` | passed: 39 tests | new public adapter seam plus unchanged TextInput and feedback behavior |
| `dart test test/component_acceptance_matrix_test.dart --reporter expanded` | passed: 144 tests | existing rich/linear public component matrix |
| `dart run tool/check_doc_links.dart` | passed: `Checked 151 relative links in 24 Markdown files.` | documentation links |
| `dart test --reporter compact` | passed: 647 test completions, `All tests passed!` | full package suite |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario repeat -Report doc/evidence/trelis-backend/ticket-02-text-input-repeat.txt` | passed: `alpha,alpha`; console state `503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` | focused legacy Windows native TextInput lifecycle; stored report: [ticket-02-text-input-repeat.txt](ticket-02-text-input-repeat.txt) |

## Acceptance mapping and limitations

- **B-BASE:** the existing baseline evidence remains the behavioral starting
  point. This ticket added deterministic public adapter acquisition,
  restoration, environment, input/output, and injected-failure observations;
  it did not reinterpret host redirection as synthetic adapter capability.
- **B-CAP:** selected input/output and the existing single rich-capability fact
  are exposed at the adapter boundary. Field-level output profiles, geometry,
  capability precedence, selected stderr/stdout native observations, and
  `NO_COLOR` interpretation are ticket 03/04 work and remain unverified here.
- **B-FAIL:** deterministic acquisition, write, and restoration failures are
  observable at public boundaries. Concurrent cleanup failures, native failure
  preservation, watcher/registration retirement, and forced-kill behavior are
  not covered by this ticket and remain later work.

The native Windows probe exercised the retained legacy native path, not an
external `TerminalIo` implementation. It confirms the focused existing repeat
lifecycle remained green but is not a native qualification of the new adapter.
Linux/macOS PTY execution, CI runs/artifacts, visible GUI/NVDA observations,
and terminal/font/geometry claims were not performed. This evidence makes no
whole-library accessibility or cross-platform pass claim.
