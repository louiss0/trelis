# Ticket 12 — scoped sequential TextInput session evidence

**Status:** pass for this tracer-bullet scope  
**Source revision:** `eaac422` (this ticket implementation commit; based on `1dfc564815460fcb822052d190a2e992aeadfecc`)  
**Date:** 2026-04-13  
**Environment:** Windows; Dart SDK as selected by the repository; scripted streams and recording terminal adapter (no physical terminal required).

## Public-behavior scenarios

`test/terminal_session_test.dart` exercises the public `TerminalSession.run` and `TextInput.prompt(session:)` seams:

- a single `ScriptedInput` stream supplies successive linear TextInput prompts (`Ada`, then `Lovelace`), preserving buffered parsed input through one session-owned key router;
- a second overlapping attached prompt fails with `StateError` before the controlled stream receives a key;
- attached prompts inherit the session configuration; competing source configuration fails with `ArgumentError`; closed handles reject subsequent prompts;
- callback exceptions propagate, while scope teardown retires the handle;
- a session with a `TerminalIo` acquires no lease before a prompt and records exactly `acquire`, `restore` around the attached prompt.

## Commands and results

| Command | Result |
| --- | --- |
| `dart test test/terminal_session_test.dart --reporter expanded` | 5 tests passed |
| `dart test test/terminal_io_test.dart test/linear_text_input_events_test.dart test/text_input_test.dart --reporter expanded` | 31 tests passed |
| `dart analyze` | `No issues found!` |
| `dart test --reporter expanded` | 670 tests passed |
| `dart format --output=none --set-exit-if-changed .` | exited successfully (it reported pre-existing formatting normalization in two test files, with no resulting tracked diff) |
| `dart run tool/check_doc_links.dart` | checked 152 relative links in 29 Markdown files |

## Limitations

This is public scripted/adapter verification on Windows, not native PTY, Linux/macOS CI, visible-terminal, compositor, feedback-region, resize, or modal-help evidence. Those acceptance areas remain for their dedicated tickets and the final backend gate. No claim of whole-library accessibility or platform-native coverage is made here.
