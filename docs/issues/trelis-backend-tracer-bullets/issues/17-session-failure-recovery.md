# 17: Isolate region faults and recover safely from session failures

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Keep unrelated regions usable after a local fault and restore the terminal safely when the shared output fails.

**Blocked by:**
- [15: Make help modal while background work keeps updating](15-modal-help-live-jobs.md)
- [16: Preserve the prompt and important notices on short screens](16-short-screen-overflow.md)

**Status:** resolved

**Acceptance reference:** [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail), [B-SESSION](../../trelis-backend-implementation/spec.md#b-session), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret).

- [x] Distinguish local registration/render failures from shared writer/native failures and use safe diagnostics.
- [x] Exercise failures during modal help, overflow/history commit, resize and callback teardown through the public session.
- [x] Retire generations, drain supported output, stop watchers, release leases and restore received state on every supported exit.
- [x] Preserve original failure context when cleanup also fails, without inventing an application job outcome.
- [x] Assert late callbacks cannot write after retirement/closure and document forced-termination/external-writer limits.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-17-failure-recovery` in commits
`54572dc235144a149951ed056b4df8062f149678` (session retirement and writer
routing), `5ed2ae528c910f581fba6b84ea6c591eff453309` (public failure-recovery
tests), and `986c241` (evidence). The branch is based on integration
`aae33d028c4d097845b95aeaefe8bce4db6c2d6e`; the integration tip had not moved,
so no merge commit was required. It was not merged into integration.

`TerminalSession` now routes prompt and session painting through one serialized
shared writer. A writer failure retires every live generation, clears the
repaint/geometry anchors, removes feedback registrations, closes the reader,
releases the screen claim, and lets the original failure reach the caller; local
registration, validation and geometry-probe faults stay local and leave
unrelated regions usable. A failed repaint observed by a detached resize
notification is delivered to the pending prompt instead of being swallowed as a
geometry fault, so the prompt ends with the original error and the resize
subscription/poll stop. Cleanup collects its first failure and reports
`TerminalSessionCleanupException` (session) or `TerminalRestorationException`
(terminal lease) with both original error objects, while their diagnostics no
longer stringify embedded error text, so application data and secret drafts are
not copied into a message. Late updates on retired regions perform no writes and
a closed handle rejects new prompts, regions and standalone-writer registration.

Evidence is in `doc/evidence/trelis-backend/17-session-failure-recovery.md`:
`test/terminal_session_failure_recovery_test.dart` drives `TerminalSession`,
`TextInput`, `Text`, `Spinner`, `Progress`, `ScriptedInput`, `TerminalIo` and
`TerminalResizeObserver` with conditional-throwing sinks, a failing reader, and
recording adapters. Verification on Windows 11 with Dart SDK 3.13.2: the focused
failure-recovery suite passed 10 tests, the related session/session-feedback/
modal-help/short-screen/resize/terminal-io suites passed 32 tests, `dart
analyze` reported no issues, `dart format --set-exit-if-changed` reported no
changes, `dart run tool/check_doc_links.dart` checked 152 links in 42 files, and
the full suite passed 714 tests.

Limitations: this is deterministic scripted-writer fault injection, not a native
PTY probe. Recovery is only claimed for supported exits — forcible process
termination and unmanaged external writers are out of scope, and a session whose
shared writer failed cannot restore terminal state through that writer (it
retires instead of writing to an unknown fallback, so an alternate screen may be
left as last seen). The writer contract is a synchronous `StringSink`, so there
is no asynchronous buffer to drain. Linux/macOS CI, native PTY scenarios, Windows
GUI/NVDA evidence and final backend-gate acceptance remain outstanding under
their own tickets. Two of the new tests (local registration isolation, native
acquisition failure) lock behavior the working branch already contained before
this ticket's completion rather than new production code.

## Comments

**Combined integration merge.** Merged follow-up branch tip `226d6c8` as `de42393` without conflict. The session reader failure signal, terminal-adapter-owned reader and idempotent `_Keys.fail` are retained; the documented real-console limitation remains. At combined revision `74c5171`, 275 targeted tests and 813 full-suite tests passed; `dart analyze` reported no issues, changed-Dart formatting reported 8 files / 0 changed, and the doc-link check reported 153 links in 54 files. Native/GUI/cross-platform limitations remain as documented.


**Review follow-up (2026-11-13, after merge as `9d6ecbe`).** Concern:
`_closeAfterSharedWriterFailure` retired the session but did not signal a
pending `_keys`; only the resize callback called `keys.fail`. A feedback
write failing while the prompt was idle, with the caller catching that
exception, left the prompt parked forever.

Confirmed as a real defect for public sessions, not caller misuse: catching a
feedback write failure is legitimate, and the prompt then still had to decide.
Before the fix the scenario timed out with the prompt parked (scripted sessions)
and, after the scripted fix, also for `TerminalIo`-backed sessions.

Fixed on `ticket/backend-17-failure-recovery` in
`d85a6982b6ae3f187fd19f97300a2ea40b19fcfa` (retirement now fails the
session-owned reader with the original error; `_Keys.fail` keeps only the
first failure so the resize repaint and the session cannot deliver the same
writer failure twice; a `TerminalIo` session now owns its reader via the same
`_Keys(input.transform(utf8.encoder))` construction the components already
used), `76e356cff11cdb6ce4c158d02180374a2e8b84be` (tests) and `226d6c8`
(evidence). The previous overflow test discarded an active prompt future, which
is now caller misuse; it awaits the prompt so the failure surfaces through it.

Verification at `226d6c8` on Windows 11 with Dart SDK 3.13.2: failure-recovery
suite passed 13 tests, related session/feedback/modal-help/short-screen/resize/
terminal-io suites passed 35 tests, `dart analyze` reported no issues,
`dart format --set-exit-if-changed` reported no changes,
`dart run tool/check_doc_links.dart` checked 152 links in 42 files, and the
full suite passed 717 tests. `doc/evidence/trelis-backend/17-session-failure-recovery.md`
records the contract, red-before-fix evidence and limitations.

Remaining limitation recorded rather than changed unverified (superseded by the native-console follow-up below): a prompt on the
real console (session `run` with neither `terminal:` nor `source:`) still
creates its own reader, so retirement surfaces at the next interaction instead
of pre-empting the blocking console read; the native console key path cannot be
exercised deterministically here. A callback that abandons an active prompt
future (starts it, never awaits it, returns) is covered: the scope closes the
reader and the prompt ends as `InputEnded` with no writes after closure.

**Native-console ownership follow-up (2026-11-13, on
`ticket/backend-17-failure-recovery`).** The limitation above is now fixed.
Concern: the real console path still let the component create its own reader,
so a session with neither `terminal:` nor `source:` had no session-owned
reader. Retirement retired the regions, but the prompt stayed parked on the
blocking console read until the next key, and a discarded prompt left the
console poll running. Determinism was not the obstacle the earlier note
assumed: the defect reproduces through the existing Windows console probe.

Fixed in `bda95ce269fa04676764f59b0ebce1e931e5fcfa` (a session now owns one
reader per selected input stream — reused while the stream is unchanged, so
buffered input, open escape sequences and paste provenance survive sequential
prompts, and replaced and closed when it changes; the console transport's
per-prompt stream gets a per-prompt session-owned reader that retirement
fails, closed before terminal modes are restored; `_Keys.close` and
`_Keys.fail` are idempotent), tested in
`4157918d2b83fc619cc2f894e4ffe2a2aeaef326` (two deterministic public-session
tests: a `TerminalIo` adapter that selects a fresh stream per prompt is
answered from that stream and detaches the replaced reader; retirement ends
the prompt of the currently selected input), merged with integration
`74c5171bdd794b69262558130aa64195b68ec57b` as
`156cf4c7188cf6c8a84bbf3f9898aa32db9c9e61`; evidence commit `e7addc5`. Not
merged into integration.

Verification at `156cf4c` on Windows 11 (`10.0.26200`) with Dart SDK
`3.13.2 (stable)`: 86 targeted session/feedback/modal-help/short-screen/
resize/terminal-io/output-profile/boolean/key-capture tests passed, the full
suite passed 815 tests, `dart analyze` reported no issues, the three changed
Dart files are formatter-clean, and `dart run tool/check_doc_links.dart`
checked 153 links in 49 files. Native Windows console probe: `session-retire`
passed twice with real console modes (`503 -> 496` acquired `-> 503` restored,
`result=retired`), `rich` still passes, and the session-based key-capture path
(`key_capture_windows.ps1 -Scenario rich`) still passes. Red before the fix:
the same probe reported `FAIL probe process did not exit` — the parked prompt
could not be ended and its console poll kept the process alive.

Limitations: the POSIX counterpart (`session-retire` in
`test/posix_terminal_pty.py`) is wired into the `posix-native` CI job but was
not executed here (no POSIX PTY on this host), so it is not claimed as
evidence; the native run injects the writer failure through the selected sink,
so prompt painting on the physical terminal is not exercised; the
repository-wide `dart format --set-exit-if-changed .` gate still fails on
three pre-existing files this ticket does not touch. Windows GUI/NVDA,
Linux/macOS CI and final backend acceptance remain open under their own
tickets.

**Integration merge (2026-11-13).** Merged branch tip
`e7addc5b690399dddd8a90cc5f0d8e55bf7c6980` into
`integration/trelis-backend-tracer-bullets` as
`091164f39d13c90508a7e265de28a4341ce88e55` (`--no-ff`, 2 parents
`8e54b8c` + `e7addc5`). No conflicts: git reported "Merge made by the 'ort'
strategy" and the only files the merge brought in are
`.github/workflows/platform-regression.yml`, the ticket evidence document,
`lib/src/text_input.dart`, `test/posix_terminal_pty.py`,
`test/terminal_session_failure_recovery_test.dart`,
`test/text_input_native_app.dart` and `test/text_input_windows.ps1` (+448/−58).
The integration tip already carried the filesystem-27 migration merge
(`8e54b8c`); its `lib/src/path_input.dart`, `lib/src/filesystem_picker.dart`,
README, tests and evidence are byte-identical before and after this merge, so
the `capturedBase` capture forwarding and the "the session owns the reader, so
the component does not close it" contract (`if (keys == null) await
inputKeys.close();`) are preserved unchanged. The session-owns-one-reader-per-
stream change composes with them: `_promptRunner` still hands the component the
session-owned `_Keys`, and `_readerFor` now reuses that reader while the
selected stream is unchanged and replaces it when it changes.

Validation at merged revision `091164f` on Windows 11 (`10.0.26200`) with Dart
SDK `3.13.2 (stable)`, `windows_x64`:

| Command | Result |
| --- | --- |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test test/terminal_session_failure_recovery_test.dart test/terminal_session_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/idle_text_input_resize_test.dart test/terminal_io_test.dart test/output_profile_text_input_test.dart test/boolean_test.dart test/key_capture_test.dart --reporter compact` | Passed: 86 tests. |
| `dart test --reporter compact` | 837 passed, 2 failed (839 total); both failures are pre-existing and path-length sensitive, see below. |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/terminal_session_failure_recovery_test.dart test/text_input_native_app.dart` | Passed: `Formatted 3 files (0 changed)`. |
| `dart format --output=none --set-exit-if-changed .` | Failed on the same three pre-existing files outside this ticket (`test/linear_text_input_events_test.dart`, `test/native_text_input_capabilities_test.dart`, `test/terminal_session_short_screen_test.dart`): `Formatted 146 files (3 changed)`. Left unchanged. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 153 relative links in 55 Markdown files.` (55 rather than 49 because of untracked `docs/` and `doc/research/` files present in this working tree). |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario session-retire -Report <temp>` (twice) | Passed both runs: `text input session-retire PASS result=retired state=503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario rich -Report <temp>` | Passed: `text input rich PASS result=alpha state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/key_capture_windows.ps1 -Scenario rich -Report <temp>` (twice) | Passed both runs: `key capture PASS result=A:control+shift:observed,C:shift:observed state=503:7:25:1 -> 503:7:25:1 -> 503:7:25:1`. |

The two full-suite failures are
`test/filesystem_migration_test.dart: PathInput stage help rich help is
stage-led and preserves the draft` and `test/path_input_behavior_test.dart:
rich entry preserves invalid draft and context`. They are not caused by this
merge: both files and `lib/src/path_input.dart` are unchanged by it, and the
same two files fail with `lib/src/text_input.dart` reverted to `8e54b8c`
(checked out for one run, then restored; worktree hash verified). Cause is the
100-column hard wrap of `PathInput` copy that embeds `Directory.current.path`
before the asserted phrases: at this working directory
(`C:\Users\bvlou\projects\prompty`) `no link canonicalization` and `Target
must exist` straddle a wrap boundary, while the identical sources pass in
`prompty-backend-ticket-27` (`...\prompty-backend-ticket-27`), where the
longer base string shifts the break. The key-capture `during` snapshot above
reads `503` rather than the `496` recorded earlier; the same probe on
`prompty-backend-ticket-17` at `e7addc5` also reports `503 -> 503 -> 503`
today, so this is a host/timing observation, not a merge regression, and the
probe's own assertions and restored state still pass.

Limitations carried forward: the POSIX `session-retire` probe is still
unexecuted on this host (no POSIX PTY) and remains unclaimed evidence; the
native probes inject the writer failure through the selected sink, so physical
prompt painting is not exercised; Windows GUI/NVDA, Linux/macOS CI and the
final backend acceptance gate remain open under their own tickets. The
integration lock (`.git/pi-integration-merge.lock`) was held for the merge and
all validation, and a stale lock left by the previous filesystem-27 merge
(dead pid, same host, no `MERGE_HEAD`) was quarantined as
`.git/pi-integration-merge.lock.stale.20261114T012154299Z` rather than
overwritten.
