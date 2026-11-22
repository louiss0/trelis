# Ticket 17 — region fault isolation and session failure recovery

**Status:** pass for the scripted, `TerminalIo` and native-console public
shared-session seams.

## Source and environment

- **Implementation revision:** `54572dc235144a149951ed056b4df8062f149678`
  (`feat: retire shared sessions safely after writer failures`) plus the review
  follow-up `d85a6982b6ae3f187fd19f97300a2ea40b19fcfa`
  (`fix: end an idle prompt when its session retires`).
- **Test revisions:** `5ed2ae528c910f581fba6b84ea6c591eff453309` and the review
  follow-up `76e356cff11cdb6ce4c158d02180374a2e8b84be`.
- **Branch:** `ticket/backend-17-failure-recovery`, based on integration
  `9d6ecbe` (the ticket's own merge); the follow-up commits are not merged.
- **Native-console follow-up:** implementation
  `bda95ce269fa04676764f59b0ebce1e931e5fcfa`
  (`fix: own every session prompt reader, including the native console`), tests
  `4157918d2b83fc619cc2f894e4ffe2a2aeaef326`, merged with integration
  `74c5171bdd794b69262558130aa64195b68ec57b` as
  `156cf4c7188cf6c8a84bbf3f9898aa32db9c9e61`; not merged into integration.
- **Date:** 2026-11-13.
- **Environment:** Windows 11 (`10.0.26200`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`.
- **Input/output:** synthetic scripted stream input and `StringBuffer`,
  conditional-throwing and always-throwing `StringSink` observations, a
  recording `TerminalIo` adapter that records `acquire`/`restore` and can fail
  acquisition or restoration, and a `TerminalIo` adapter that selects a fresh
  input stream and lease per prompt. The native console runs use the real
  console input handle and real terminal modes with an injected failing output
  sink.
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
  retired scope still restores its lease;
- a session keeps one reader per selected input stream: a `TerminalIo` adapter
  that selects a fresh input stream for each prompt is answered from that
  stream, the replaced reader is detached from its old input, and each prompt
  still acquires and restores its own lease; and
- retirement ends the prompt of the currently selected input after that reader
  replacement, so an idle prompt is never left waiting on a stream the session
  no longer offers; and
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
`TerminalIo`-backed session owns its key reader exactly as a scripted source
does, and so does the real console (same construction the components already
performed, so no new decoding path is introduced).

The session owns one reader per selected input stream. The reader is reused
while the selected stream is unchanged, so buffered input, open escape sequences
and paste provenance survive sequential prompts without resubscribing; when the
selected stream changes, the previous reader is closed and retirement targets
the new one. The native console transport selects a fresh stream for each
prompt, so its reader is scoped to that prompt — created only after console
acquisition (lazy input), failures delivered while the prompt is parked, and
closed before the terminal modes are restored. `_Keys.close` and `_Keys.fail`
are idempotent, so prompt cleanup, reader replacement and session retirement
cannot close or fail the same reader twice. A caller that catches the feedback
failure must therefore still await or otherwise handle the prompt future:
catching and `await`ing it is supported and tested; catching it and discarding
the prompt is misuse, because the discarded future completes with that failure
as an unhandled error.

## Executed verification

At merged revision `156cf4c` on Windows 11 (`10.0.26200`) with Dart SDK
`3.13.2 (stable)`:

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/terminal_session_failure_recovery_test.dart test/text_input_native_app.dart` | Passed: `Formatted 3 files (0 changed)`. |
| `dart format --output=none --set-exit-if-changed .` | Failed on three files this ticket does not touch (`test/terminal_session_short_screen_test.dart`, `test/linear_text_input_events_test.dart`, `test/native_text_input_capabilities_test.dart`): the current formatter rewrites their argument lists. Pre-existing at integration `74c5171`; left unchanged rather than reformatting unrelated files. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test test/terminal_session_failure_recovery_test.dart test/terminal_session_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/idle_text_input_resize_test.dart test/terminal_io_test.dart test/output_profile_text_input_test.dart test/boolean_test.dart test/key_capture_test.dart --reporter compact` | Passed: 86 tests. |
| `dart test --reporter compact` | Passed: 815 tests. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 153 relative links in 49 Markdown files.` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario session-retire -Report <path>` (twice) | Passed both runs: `text input session-retire PASS result=retired state=503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario rich -Report <path>` | Passed: `result=alpha state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/key_capture_windows.ps1 -Scenario rich -Report <path>` | Passed: `key capture PASS result=A:control+shift:observed,C:shift:observed state=503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. |

At the pre-fix revision (`lib/src/text_input.dart` from `226d6c8`, native app
and probe from `4157918`):

| Command | Result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario session-retire -Report <path>` | Failed: `text input session-retire FAIL probe process did not exit`. |

Red-before-fix reading of that run: with the component-owned native reader the
caught writer failure never reached the parked prompt, the in-app prompt timeout
could not end it either, and the console poll kept the process alive until the
harness killed it. With the session-owned reader the same scenario reports
`retired` and restores the received input mode.

Earlier revision (`226d6c8`, scripted and `TerminalIo` seams):

| Command | Result |
| --- | --- |
| `dart test test/terminal_session_failure_recovery_test.dart --reporter expanded` | Passed: 13 tests. |
| `dart test ...` (session/session-feedback/modal-help/short-screen/resize/terminal-io suites) | Passed: 35 tests. |
| `dart test --reporter expanded` | Passed: 717 tests. |

Red-before-fix evidence at that revision, both with `--timeout 15s`: the
caught-idle-feedback scenario timed out (the prompt stayed parked) for scripted
sessions before `d85a698` and for terminal-adapter sessions before the
session-owned reader in the same commit. Before `bda95ce`, the two new
deterministic tests fail: the per-prompt input adapter's second prompt never
receives its own input (`TimeoutException`, the session answered from the first
prompt's stream) and the retirement case hangs the same way.

## Limitations

This is deterministic scripted behavior plus one injected-failure native console
run, not a general native terminal/PTY fault injection. The sinks record composed
terminal writes, and the native runs inject the writer failure through the
selected sink, so prompt painting is recorded rather than sent to the physical
terminal; no evidence here covers physical alt-screen restoration, scrollback,
font width, or caret behavior in a real terminal.

- **Native console sessions:** the real console path
  (`TerminalSession.run` without `terminal:` or `source:`) now owns its reader
  per prompt, so retirement ends an idle prompt instead of waiting for the next
  key. The Windows console probe exercises this with a real console input handle
  and real terminal modes; the `during` snapshot `496` shows the acquired input
  mode and the restored `503` matches the pre-run state. The POSIX counterpart
  (`session-retire` in `test/posix_terminal_pty.py`) is wired into the
  `posix-native` CI job but **was not executed here** (no POSIX PTY on this
  host); its result is unverified and is not claimed as evidence.
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
- **Whole-tree formatting:** the repository-wide format gate currently fails on
  three pre-existing files outside this ticket, as recorded above. Every file
  this ticket changes is formatter-clean.
- **Replaced readers:** when the selected input changes, any partially buffered
  escape sequence or paste belongs to the transport that was replaced and is
  dropped with its reader. The console contract makes that unreachable in
  practice (each console transport belongs to exactly one prompt and the session
  refuses a second active prompt), but a synthetic adapter that swaps streams
  mid-sequence loses that fragment.
- Windows GUI/NVDA, Linux/macOS CI and native PTY runs, and final backend
  acceptance evidence remain pending their dedicated tickets and gate. The
  Windows console probe runs recorded here used the real console through
  `AttachConsole`; they are not GUI, NVDA or physical-keyboard evidence.
