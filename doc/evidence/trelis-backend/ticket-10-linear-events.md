# Ticket 10 — linear TextInput event evidence

**Date:** 2026-10-14  
**Source tested:** `abe1c6ebcc431e9f6529b42536cceaf4beb26389` plus the Ticket 10 working-tree changes recorded in this commit  
**Environment:** Windows x64; Dart SDK 3.13.2 stable; agent process streams redirected.

## Public seam and scenarios

The new public seam is `ScriptedInput(transcript: TextInputTranscript())` used
through `TextInput.prompt`. `TextInputTranscript.currentView` is the current
editable snapshot (including grapheme caret index and paste presence); its
ordered `events` have per-run ids and are deliberately separate.

`test/linear_text_input_events_test.dart` exercises this public seam:

- two validation attempts with the same text are two distinct `validation`
  events, while each submission remains separately ordered;
- a left-arrow caret-only change updates the current view from caret 2 to 1
  without appending a repaint/history event;
- two fresh identical help requests retain distinct ids; and
- an identified pasted `/cancel` is accepted literally and its submitted event
  retains literal and paste provenance.

The implementation emits only explicit opening/help/validation/submission and
terminal-outcome occurrences. It does not create events from `onChanged`,
current-view differences, no-op keys, or output repaint/resize activity.

## Commands and results

| Command | Result |
| --- | --- |
| `dart test test/linear_text_input_events_test.dart test/text_input_test.dart test/output_profile_text_input_test.dart test/native_text_input_capabilities_test.dart --reporter expanded` | Passed: 37 tests. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario redirected -Report doc/evidence/trelis-backend/ticket-10-redirected.txt` | Passed. The report records `result=alpha`, no harness failure, and console state `503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. The harness verifies the selected redirected transcript is stable and contains no ANSI. |

## Limitations

The transcript tests are deterministic scripted public-prompt checks, not a
claim of a shared multi-prompt session/router (Ticket 12) or native resize
notifications. The redirected check uses injected Windows console records; it
does not establish real keyboard, clipboard, GUI, or cross-platform terminal
behavior.
