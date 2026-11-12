# Ticket 16 — short-screen shared-session composition

**Status:** pass for the scripted public shared-session seam.

## Source and environment

- **Implementation revision:** `df3cac707da45a75ce2f6928145b1f4002bb6b2a`.
- **Branch:** `ticket/backend-16-short-screen`.
- **Date:** 2026-11-12.
- **Environment:** Windows 11 (`10.0.26200.0`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`.
- **Input/output:** synthetic scripted stream input and `StringBuffer` output.
- **Profiles:** declared 40-column ASCII monochrome rich output with one, two,
  and five rows. Resize observations deliberately include zero rows.

## Public behavior exercised

`test/terminal_session_short_screen_test.dart` uses only the public
`TerminalSession`, `TextInput`, `Spinner`, `Progress`, `MultiSpinner`,
`ScriptedInput`, `OutputProfile`, `TerminalResizeObserver`, and
`TextInputTranscript` seams. It verifies that:

- a two-row session reserves one row for the active prompt/caret and represents
  three feedback regions as the stable registration-order summary
  `Feedback (3): Index, Upload +1`;
- a one-row session retains the prompt and writes a failed Spinner outcome in
  full reviewable history, while its composed feedback line retains the `[!]`
  severity indicator after the region retires;
- zero resize observations are ignored rather than fabricated, so short
  composition remains valid; a later five-row observation restores ordinary
  per-region rendering; and
- the final composed prompt retains the `demo` draft and logical caret 4, while
  resize/repaint activity records no duplicate presentation event (only the
  opening and one submission occurrence).

The session compacts only when current feedback would exceed the rows remaining
after reserving the editable prompt row. It uses display-cell measurement before
adding labels, retains registration order, does not add a scrolling key or
change prompt interaction mode, and leaves warnings, errors, and explicit
outcomes as full transcript records.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart` | Passed: `Formatted 1 file (0 changed)`. |
| `dart test test/terminal_session_short_screen_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/idle_text_input_resize_test.dart --reporter expanded` | Passed: 12 tests. |
| `dart analyze` | Passed: `No issues found!`. |
| `git diff --check` | Passed: no whitespace errors. |
| `dart run tool/check_doc_links.dart` | Passed: checked 152 relative links in 41 Markdown files. |
| `dart test --reporter expanded` | Passed: 704 tests. |

## Limitations

This is deterministic scripted behavior, not a native terminal/PTY visual
probe. The `StringBuffer` records composed terminal writes and public prompt
views, but it does not establish physical scrolling, scrollback, font-width,
alternate-screen, or caret behavior in a real terminal. Windows GUI and NVDA,
Linux/macOS CI/native runs, shared-writer fault injection, and final backend
acceptance evidence remain pending their dedicated tickets and gate.
