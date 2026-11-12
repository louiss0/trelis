# Ticket 19 — boolean prompt migration evidence

**Status:** pass for the scripted public Boolean prompt seam.

## Source and environment

- **Implementation revision:** `f29e3373adf9bed8d541a24a25fa7b3300be6b1a`
- **Branch:** `ticket/backend-19-boolean`
- **Date:** 2026-11-12
- **Environment:** Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK 3.13.2 stable
- **Input/output:** synthetic `Stream<String>` input and `StringBuffer` output,
  plus a public `TerminalIo` fake that records acquisition/restoration
- **Rich profiles:** explicitly declared cursor support and 80×24 geometry;
  colour scenario declared RGB depth, and the no-colour scenario supplied
  `NO_COLOR=1`

## Public behavior exercised

`test/boolean_test.dart` invokes `Confirm`, `Checkbox` and `Toggle` only through
public constructors and `prompt`. It verifies that:

- each kind retains a `bool` result, an independently visible default and
  draft, its rich draft gesture, and explicit Enter completion;
- linear `yes`/`y`, `no`/`n`, empty-default, exact `/help` and `/cancel`, quoted
  literal/paste, interruption, input-ended, unavailable and supplied-answer
  outcomes remain distinct;
- rich and linear component help describes the kind-specific control and
  linear default/command rules, while dismissal leaves default and draft state
  visible;
- declared profiles and a `TerminalIo` lease reach Boolean prompts, and a
  palette produces owned RGB ANSI only when the profile allows it; `NO_COLOR`
  suppresses it;
- an explicit `TerminalSession` runs a live `Spinner` while a `Toggle` changes
  and accepts its foreground draft, preserving the status update and the
  accepted terminal outcome.

`test/component_acceptance_matrix_test.dart` supplies public rich and linear
Boolean tasks alongside the component matrix. `test/terminal_session_feedback_test.dart`
exercises the shared feedback/session behavior that Boolean prompts attach to.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/boolean_test.dart` | Passed: no formatting changes required |
| `dart test test/boolean_test.dart test/component_acceptance_matrix_test.dart test/terminal_session_feedback_test.dart --reporter expanded` | Passed: 159 tests |
| `dart analyze` | Passed: `No issues found!` |
| `dart test --reporter expanded` | Passed: 698 tests |

## Limitations

This record is deterministic scripted public-behavior evidence at the listed
implementation revision. It is not native PTY, visible-terminal, screen-reader,
Linux/macOS CI, resize/short-screen, modal-help, fault-injection or final
backend-gate evidence; those remain owned by their dedicated tickets and the
final evidence gate. It does not make a whole-library accessibility claim.
