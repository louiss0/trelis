# Ticket 15 — modal help while background work remains live

**Status:** pass for the scripted public shared-session seam.

## Source and environment

- **Implementation revision:** `fd20fd69496c38728f416d76d5adbd34ff8bfbf8`.
- **Branch:** `ticket/backend-15-modal-help`.
- **Date:** 2026-11-12.
- **Environment:** Windows 11 (`10.0.26200.0`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`.
- **Input/output:** synthetic scripted stream input and `StringBuffer` output.
- **Profiles:** explicitly declared 40×8 ASCII monochrome rich profiles, with
  alternate-screen support both enabled and disabled.

## Public behavior exercised

`test/terminal_session_modal_help_test.dart` invokes public `TerminalSession`,
`Spinner`, `Text`, `TextInput`, `ScriptedInput`, `OutputProfile`, and
`TextInputTranscript` seams. It verifies that:

- session help, rather than independently painting regions, owns the
  alternate-screen enter/leave sequence;
- a Spinner update and a warning Text notice received during help are retained
  and written after the alternate screen is left, before the prompt is
  repainted;
- the answer draft and logical caret survive help (`de` becomes `demo`, with
  caret 4), so dismissal restores current prompt state instead of a snapshot
  from help entry;
- a rich profile without alternate-screen support uses transcript help without
  terminal alternate-screen controls, pauses region painting, and still
  retains the latest feedback on Ctrl+C interruption; and
- EOF and a session callback error both leave the alternate screen and retain
  the last background status. Existing `text_input_help_test.dart` verifies
  the truthful Ctrl+T and linear `/help` routes, literal-command wording, and
  raw interruption/EOF outcomes without advertising capture or literal-entry
  commands that do not exist.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | Passed: no files needed formatting. |
| `dart test test/terminal_session_modal_help_test.dart --reporter expanded` | Passed: 3 tests. |
| `dart test test/terminal_session_feedback_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart --reporter expanded` | Passed: 9 tests. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test --reporter expanded` | Passed: 701 tests. |
| `git diff --check` | Passed: no whitespace errors. |

## Limitations

This is deterministic scripted behavior, not a native terminal or PTY visual
probe. It does not qualify actual alternate-screen/caret rendering on Windows
Terminal, Linux, or macOS; test screen-reader behavior; inject shared-writer
failures; or provide the required cross-platform CI and agent-GUI evidence.
Those remain pending dedicated tickets and the final backend gate.
