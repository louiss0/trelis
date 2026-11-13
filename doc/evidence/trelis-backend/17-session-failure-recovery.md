# Ticket 17 — region fault isolation and session failure recovery

**Status:** pass for the scripted/public-terminal public shared-session seam.

## Source and environment

- **Implementation revision:** `54572dc235144a149951ed056b4df8062f149678`
  (`feat: retire shared sessions safely after writer failures`) plus the review
  follow-up `d85a6982b6ae3f187fd19f97300a2ea40b19fcfa`
  (`fix: end an idle prompt when its session retires`).
- **Test revisions:** `5ed2ae528c910f581fba6b84ea6c591eff453309` and the review
  follow-up `76e356cff11cdb6ce4c158d02180374a2e8b84be`.
- **Branch:** `ticket/backend-17-failure-recovery`, based on integration
  `9d6ecbe` (the ticket's own merge); the follow-up commits are not merged.
- **Date:** 2026-11-13.
- **Environment:** Windows 11 (`10.0.26200`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`.
- **Input/output:** synthetic scripted stream input and `StringBuffer`,
  conditional-throwing and always-throwing `StringSink` observations, and a
  recording `TerminalIo` adapter that records `acquire`/`restore` and can fail
  acquisition or restoration.
- **Profiles:** declared 40-column ASCII monochrome rich output with eight rows,
  a one-row overflow profile, and a rich profile declaring alternate-screen
  support. Geometry observations are declared, not read from the host terminal.

## Public behavior exercised

`test/terminal_session_failure_recovery_test.dart` uses only the public
`TerminalSession`, `TextInput`, `Text`, `Spinner`, `Progress`, `ScriptedInput`,
`TerminalIo`, `TerminalResizeObserver`, `OutputProfile`,
`TerminalRestorationException`, and `TerminalSessionCleanupException` seams. It
verifies that:

- a local validation fault (`Progress.update` beyond its total) leaves the other
  registered regions and their later writes usable;
- a local registration fault (a standalone `Text` writer on an output its
  session already owns) is rejected without disturbing the session writer;
- a failed shared writer retires every registration, so a late `Spinner` update
  performs no write and a new region or `Text` cannot be added;
- a failed writer during modal help and during overflow/history commit ends the
  scope with the original failure, without writing a `completed`/`failed`
  outcome the application never reported;
- a failed resize repaint ends the pending prompt with the original failure
  (without waiting for another keystroke), stops the geometry subscription, and
  leaves the retired session inert;
- a callback failure plus reader-teardown failure reports
  `TerminalSessionCleanupException` retaining both original error objects, and
  its diagnostic does not stringify them;
- a prompt failure plus native restoration failure reports
  `TerminalRestorationException` retaining both original error objects, with the
  terminal restored (`acquire`, `restore`) and no application text in the
  diagnostic;
- a native acquisition failure ends the scope with that failure, writes nothing
  to the selected output, and releases the output claim so a later session can
  own the same sink;
- a terminal-backed session whose shared writer fails still restores its
  acquired lease (`acquire`, `restore`);
- a feedback write failure that the caller catches still ends the idle prompt
  (scripted and terminal-adapter sessions) with that same failure, and the
  retired scope still restores its lease; and
- a prompt the callback abandons (started, never awaited, scope returns) ends as
  `InputEnded` at closure instead of staying pending, and writes nothing after
  closure.

The implementation retires the live generations, clears the repaint/geometry
anchors, retires and removes feedback registrations, stops the prompt's resize
subscription and fallback poll, closes the session-owned reader, releases the
screen claim, and restores the prompt lease on every supported exit. A failed
repaint observed by a detached resize notification is delivered to the pending
prompt instead of being swallowed as a geometry observation fault; geometry
probe failures remain best-effort. Diagnostics for session cleanup and terminal
restoration deliberately omit the embedded error text, so application data and
secret drafts are not copied into an exception message.

### Retirement contract for an active prompt

A failed shared writer retires the session and ends the active prompt with the
original failure; the prompt must not wait for input that can never be acted on.
The session-owned reader carries that failure, and the reader records only the
first one so a detached resize repaint and the session cannot deliver the same
writer failure twice. To make that hold for every reader a session can own, a
`TerminalIo`-backed session now owns its key reader exactly as a scripted source
does (same construction the components already performed, so no new decoding
path is introduced). A caller that catches the feedback failure must therefore
still await or otherwise handle the prompt future: catching and `await`ing it is
supported and tested; catching it and discarding the prompt is misuse, because
the discarded future completes with that failure as an unhandled error.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart lib/src/terminal_io.dart test/terminal_session_failure_recovery_test.dart` | Passed: `Formatted 3 files (0 changed)`. |
| `dart test test/terminal_session_failure_recovery_test.dart --reporter expanded` | Passed: 13 tests. |
| `dart test test/terminal_session_failure_recovery_test.dart test/terminal_session_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/idle_text_input_resize_test.dart test/terminal_io_test.dart --reporter expanded` | Passed: 35 tests. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test --reporter expanded` | Passed: 717 tests. |

Red-before-fix evidence, both with `--timeout 15s`: the caught-idle-feedback
scenario timed out (the prompt stayed parked) for scripted sessions before
`d85a698` and for terminal-adapter sessions before the session-owned reader in
the same commit; the abandoned-prompt scenario already passed and is retained as
a regression lock.

## Limitations

This is deterministic scripted behavior, not a native terminal/PTY fault
injection. The sinks record composed terminal writes, but no evidence here
covers physical alt-screen restoration, scrollback, font width, or caret
behavior in a real terminal.

- **Native console sessions:** a prompt running on the real console
  (`TerminalSession.run` without `terminal:` or `source:`) still creates its own
  key reader, so a retirement cannot pre-empt a blocking console read. The
  failure surfaces at the next prompt interaction. The same session-owned-reader
  treatment is applicable, but it would change the native console key path,
  which this environment cannot exercise deterministically (no TTY), so it is
  left for native-evidence work rather than changed unverified.
- **Caller responsibilities:** catching a writer failure and continuing to await
  the prompt is supported; discarding an active prompt future without handling
  its error, ignoring the failure and expecting further accepted input, or
  expecting terminal restoration through the failed writer are misuse.
- **Forcible termination:** recovery is only claimed for supported exits.
  `SIGKILL`/process termination or a terminal torn down without delivering a
  supported exit cannot run the cleanup path and is explicitly out of scope.
- **External writers and opaque aliases:** a writer that bypasses the session
  (another process, or a sink alias that cannot be identified) cannot be
  coordinated or made safe automatically.
- **Failed shared writer:** the session cannot restore terminal state through the
  writer that just failed. It retires state instead of emitting a fallback
  diagnostic to an unknown sink, and an alternate screen entered before the
  failure may be left as the application last saw it.
- **Draining:** the writer contract is a synchronous `StringSink`; the session
  serializes writes but has no asynchronous buffer, so there is no queued output
  to drain after a failure. A real asynchronous writer would need its own drain
  evidence.
- **Secret non-disclosure:** the diagnostics assertions use synthetic canaries in
  the failure messages; they do not establish that every application error is
  free of sensitive text, only that the session does not concatenate it into its
  own diagnostic.
- Windows GUI/NVDA, Linux/macOS CI and native PTY runs, and final backend
  acceptance evidence remain pending their dedicated tickets and gate.
