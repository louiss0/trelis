# Ticket 11 — TextInput help

- **Status:** pass for the scripted public TextInput interaction/help/transcript seams exercised below.
- **Source revision:** `d5072a7777107b0d2334dc97b046dbe2f4470a43`.
- **Date:** 2026-11-11.
- **Environment:** Windows 11 (`10.0.26200.0`), Dart SDK `3.13.2 (stable)`, `windows_x64`.

## Public behavior exercised

`test/text_input_help_test.dart` invokes only public `TextInput`, `ScriptedInput`,
`OutputProfile`, and `TextInputTranscript` seams. It verifies:

- `themeDefault`, compact, expanded, and hidden instruction policies; label and
  required/maximum-length context remain visible, and hidden guidance still
  exposes the applicable help route.
- Rich Ctrl+T full help reports the actual editing controls including Home/End,
  constraint state, interruption and cancellation; caller supplementary help
  is appended rather than replacing it. Escape resumes the draft at its prior
  logical caret and accepts the edited value.
- Linear `/help` is sequential/reviewable transcript output, retains command
  quoting and paste wording, emits a help transcript event, and retains an
  invalid draft through validation for correction.
- Ctrl+C and EOF while rich help is open return `Interrupted` and `InputEnded`
  respectively, rather than submitting or cancelling an answer.

The full suite also covers existing public validation, literal command, paste,
Unicode/caret, native capability and component behavior.

## Commands and results

```text
 dart test test/text_input_help_test.dart test/text_input_test.dart test/linear_text_input_events_test.dart --reporter expanded
 # 33 tests passed

 dart analyze
 # No issues found!

 dart test --reporter expanded
 # 680 tests passed
```

## Limitations

This record uses synthetic scripted input and `StringBuffer` output. It does
not claim a native terminal, alternate-screen visual, screen-reader, or
cross-platform validation result. Temporary-screen behavior is covered by the
existing public alternate-screen implementation; this ticket's focused test
covers the reviewable transcript fallback.
