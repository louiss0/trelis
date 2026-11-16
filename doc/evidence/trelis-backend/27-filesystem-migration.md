# Ticket 27 — path entry and filesystem browsing migration evidence

**Status:** pass for the scripted public `PathInput`, `FilePicker` and
`DirectoryPicker` seams.

## Source and environment

- **Implementation revision:** `7ddc5cf` (implementation, test and README
  commits `c634946`, `6adf6e8`, `f122574`, `6af2faf`, `7ddc5cf` on
  `ticket/backend-27-filesystem-migration`), based on integration `74c5171`.
  This record's own commits change documentation only. The branch was merged
  with `integration/trelis-backend-tracer-bullets` before this record was
  finalized; the integration branch was still at `74c5171`, which is already an
  ancestor of the branch, so the merge reported `Already up to date` and the
  revision under test did not change.
- **Branch:** `ticket/backend-27-filesystem-migration`
- **Date:** 2026-11-14
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable (`dart --version`, Tue Aug 25 01:01:12 2026 -0700)
- **Selected input/output:** synthetic `Stream<String>` input with `StringBuffer`
  output, deterministic `Directory.systemTemp.createTemp` fixtures, one public
  `TerminalIo` fake that records acquisition/restoration, and `TerminalSession`
  scenarios with a live `Spinner`.
- **Mode and profile:** rich scenarios declare cursor support and positive
  geometry (100x30, or the acceptance matrix's 100x30); linear scenarios declare
  no geometry; the colour scenario declares indexed-256 colour with an explicit
  component `ColorTheme`.
- **Geometry/width policy:** the default `TextDisplayMap` width policy with the
  declared columns capped at the shared 120-column cap. Linear scenarios are
  unwrapped because no geometry is declared.

## Public behavior exercised

`test/filesystem_migration_test.dart` (24 tests) invokes only the public
`PathInput`, `FilePicker`, `DirectoryPicker` and `TerminalSession` APIs. It
verifies that:

- an explicit rich mode without declared cursor support and positive geometry
  returns `Unavailable` and paints nothing, `automatic` mode falls back to
  linear when no geometry is declared, and the same rich scenario succeeds once
  a profile is declared;
- a public `TerminalIo` adapter is leased and restored exactly once, cannot be
  combined with `source:` or `output:`, and an attached prompt rejects competing
  invocation configuration;
- a `PathInput` and a `FilePicker` attached to an explicit `TerminalSession`
  share its reader, writer and live feedback: a `Spinner` update and its
  `[status]` line stay visible while the prompt keeps its listing, draft and
  review stage;
- both stages of path entry carry path-specific help in rich (`Ctrl+T`) and
  linear (`/help`) modes, naming the captured base, the existence and
  target-type policy, literal-path and escaping rules, `..` retention,
  drive-relative rejection, fail-closed inspection, the shared review, the
  file-browser route for link approval and the snapshot/later-operation caveat;
  help dismissal repaints and retains the draft or the review candidate, and
  help is not generic editor help;
- `/help` is cleared instead of being typed into the path, while the documented
  `\/help` escape still enters the literal `/help` path (the Windows mapping to
  a root-relative name is asserted too);
- the browse, literal-path and review stages of both pickers have their own
  help, naming `open <n>`, `choose <n>`, `path`, `parent`, `refresh`, `hidden`,
  `open <n> links` approval, the reference-versus-identity stale rule, the
  no-sandbox caveat and the later-operation limit;
- the compact opening guidance keeps the safety caveats visible outside help —
  `Links require explicit per-open approval.` and `The base is not a sandbox.`
  for the browsers, `Returned paths do not guarantee later operations succeed.`
  for `PathInput` — and they survive help and dismissal in the transcript;
- both pickers distinguish `Cancelled` and `InputEnded` in linear mode, and
  `Interrupted`, `Cancelled` and `InputEnded` in rich mode; a rich review can be
  abandoned with Escape without choosing for both the browser and `PathInput`;
- repeated browser rejections (a wrong target type, an out-of-range reference)
  restate the protected reason and keep the same listing context usable until a
  later acceptance;
- a declared `ColorTheme` styles the listing, warnings and review through the
  shared writer (`\x1b[38;5;` sequences appear) while the caveat text remains
  readable, and an undeclared profile paints no colour;
- session help opened with `Ctrl+T` keeps a live `Spinner` update withheld and
  restores the latest composite on dismissal, before the review prompt
  continues.

`test/filesystem_picker_test.dart` keeps its existing public-behavior coverage
(reuse resetting browsing state, hidden entries, `refresh` replacing displayed
references, stale references, parent navigation at a filesystem root, literal
`path` entry, per-open link approval, linked cycles and review re-inspection) at
revision `7ddc5cf`; the rich cases now declare the cursor support and geometry
that the shared profile layer requires. `test/path_input_test.dart`,
`test/path_input_behavior_test.dart` and `test/path_input_errors_test.dart` keep
their literal-path, escaping, review, interrupt and inspection-failure coverage
at the same revision. `test/component_acceptance_matrix_test.dart` supplies the
public rich and linear `PathInput`, `FilePicker` and `DirectoryPicker` tasks, and
the session suites exercise the shared feedback, modal-help and failure-recovery
behavior these prompts attach to.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/path_input.dart lib/src/filesystem_picker.dart test/filesystem_migration_test.dart test/filesystem_picker_test.dart test/path_input_behavior_test.dart` | Passed: `Formatted 5 files (0 changed)` |
| `dart analyze` | Passed: `No issues found!` |
| `dart test test/filesystem_migration_test.dart test/filesystem_picker_test.dart test/path_input_test.dart test/path_input_behavior_test.dart test/path_input_errors_test.dart --reporter compact` | Passed: 57 tests |
| `dart test test/component_acceptance_matrix_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_failure_recovery_test.dart --reporter compact` | Passed: 163 tests |
| `dart test --reporter compact` | Passed: 837 tests |
| `dart run tool/check_doc_links.dart` | Passed: 153 relative links in 50 Markdown files |

The full-suite figure includes the 24 new tests in
`test/filesystem_migration_test.dart`; no other test file gained or lost a test
in this ticket. The ticket's own help wiring was mutation-checked: removing the
`helpText`/`linearHelpText` arguments from the path-entry, path-review, browse,
literal-path and review `_edit` calls makes four of the new tests fail, so those
assertions depend on the component help rather than on ambient output (checked
separately for the path and browser wiring, then restored).

## Limitations

- This is deterministic scripted public-behavior evidence at the listed
  revision. It is not native PTY, visible-terminal GUI/NVDA, Linux/macOS CI,
  resize/short-screen, fault-injection or final-backend-gate evidence; those
  remain owned by their dedicated tickets and the final gate.
- Rich presentation is written to the transcript rather than an alternate
  screen, so vertical overflow is ordinary terminal scrollback. Only wrapping
  inside the declared width was verified. The wrap claim was initially recorded
  as "substring assertions that avoid tokens a wrap could split"; that was
  wrong, and the merge validation described at the end of this record shows two
  phrases straddling a line boundary. Content assertions now rebuild the
  displayed text across line boundaries instead of assuming a phrase lands
  inside one line.
- A lone trailing Escape at end of input reports `InputEnded` rather than
  cancellation, because the shared key parser only flushes a pending Escape for
  a session-owned reader. The tests therefore send a following inert key or use
  the session reader; this is pre-existing shared behavior, not a filesystem
  regression.
- The Windows-only link and hidden-attribute paths use junctions and
  `GetFileAttributesW`; the linked-directory cycle case and the hidden-attribute
  detection are exercised only on this Windows host, while POSIX runs a symbolic
  link through the same public scenario.
- The Windows `PathInput` inspection errors that require a denied ACL are still
  covered by `test/path_input_errors_test.dart` only; this ticket did not add a
  new denial scenario.
- Colour is verified through declared synthetic profiles. Real terminal colour
  handling, `NO_COLOR` inheritance and palette agreement remain owned by the
  colour and final-gate tickets; the `NO_COLOR` reduction itself is the shared
  profile helper covered elsewhere.
- `dart format --output=none --set-exit-if-changed .` still reports the three
  pre-existing unformatted test files on the integration tip
  (`test/linear_text_input_events_test.dart`,
  `test/native_text_input_capabilities_test.dart`,
  `test/terminal_session_short_screen_test.dart`); they are unmodified here and
  belong to their own tickets. The command was run and reported exactly those
  three files.
- Absence is not directly observable on Windows: `_pathInspectionFailure`
  calls `GetFileAttributesW` and then reads `GetLastError()` through a second
  FFI call, and that read is not atomic with the failing call. The slot can be
  lost, so a genuinely absent target is sometimes reported as
  `Cannot inspect target (Windows error 0).` instead of `Target must exist.`
  The rate measured here is about 0.05% per test invocation under concurrent
  load (7/12800 in an independent reproduction), and a single-isolate API probe
  measured 14/20000 on a short base and 2/20000 on a long base, so it does not
  depend on path length. The component stays fail-closed throughout - the
  target is refused, `FilePicker` still ends with `InputEnded` and the removed
  selection is still never accepted - and error 0 is never treated as absence.
  Only the protected *reason* wording varies, so `test/filesystem_picker_test.dart`
  and `test/path_input_behavior_test.dart` assert the refusal contract
  (candidate named, refusal present, either truthful reason, no acceptance)
  instead of exact native error fidelity. What is proven is that the last-error
  slot can be lost between two adjacent FFI calls and that the rate tracks
  allocation between them; the exact mechanism (GC or other Win32 work on the
  same OS thread versus isolate thread migration) is **not** proven, and the
  POSIX `access()`/`errno` branch has the same two-call hazard in principle but
  is untested on this Windows-only host. An atomic native capture is a
  dedicated follow-up, not part of this repair.
- The previously recorded one-off suite failure of `test/filesystem_picker_test.dart:
  acceptance rechecks a selection removed during review` is this same hazard
  plus an over-specified assertion, not the delete-during-review re-inspection
  policy and not a product regression. It is recorded separately from the pass
  claims above, and it can still occur at the measured rate until the atomic
  capture lands.
## Merge validation and repair

Merging `ticket/backend-27-filesystem-migration` into
`integration/trelis-backend-tracer-bullets` with `--no-ff` produced merge commit
`8e54b8c` (parents `74c5171` and `5b00c62`) with no conflicts, no deleted files
and every earlier migration, the guarded writer and the reader retirement
intact. Nothing in the branch reverted the integration tip, which is already an
ancestor of the ticket tip.

The first validation at that merge failed two of the 57 targeted tests:
`test/path_input_behavior_test.dart: rich entry preserves invalid draft and
context` (`contains('Target must exist')`) and
`test/filesystem_migration_test.dart: rich help is stage-led and preserves the
draft` (`contains('no link canonicalization')`). Both are wrap-position
dependent: they used `Directory.current.path` as the base and a declared
100-column geometry, so the phrase only stayed inside one line at the ticket
worktree's path length. Probing the same tree from seven working-directory
lengths (31, 38, 44, 56, 73, 92 and 116 characters, via temporary junctions)
also exposed a third one, `rich review help returns to the same review stage`,
whose `RegExp('Resolved candidate:')` count is 0 when the wording straddles a
break. Those assertions were the defect, not the wrapping: the shared writer
deliberately breaks at display cells, keeping the separator space at the start
of the continuation line or splitting a long token.

The repair keeps every assertion, and only stops assuming a phrase fits one
line. `test/filesystem_migration_test.dart` and
`test/path_input_behavior_test.dart` rebuild the displayed text with `\r`/`\n`
removed before matching content, and three tests are now parameterized over an
explicit short and long base so a worktree-length change cannot hide the same
fragility again: the two path-entry scenarios plus the path-review help
scenario. The two absence assertions assert the refusal contract instead of
native error fidelity (see the last limitation above).

Verification at integration `13b524b` (three later merges, `091164f` ticket 17,
`0c219fa` ticket 22 and `13b524b` ticket 23, landed after `8e54b8c`; none
touches these four files) with this repair applied:

| Command | Result |
| --- | --- |
| `dart analyze` | Passed: `No issues found!` |
| `dart format --output=none --set-exit-if-changed` on the three changed test files | Passed: `Formatted 3 files (0 changed)` |
| `dart format --output=none --set-exit-if-changed .` | Only the three pre-existing unformatted files listed above |
| `dart run tool/check_doc_links.dart` | Passed: 154 relative links in 58 Markdown files |
| `dart test` on the five path/filesystem suites | Passed: 60 tests |
| `dart test` on the acceptance-matrix and session suites | Passed: 165 tests |
| `dart test --reporter compact` | Passed: 913 tests |
| Same five suites from working-directory lengths 31, 38, 44, 56, 73, 92 and 116 | Passed: 60 tests at every length |

Mutation checks at the same revision, each restored to the committed source
afterwards (verified by blob hash): omitting the per-open link-approval warning
fails the caveat test; weakening the absence wording to `Missing target.` fails
the path-entry test; dropping the link-canonicalization clause fails the
path-entry help tests; and making the inspection branch accept an absent or
removed target fails both `acceptance rechecks a selection removed during
review` (it becomes `Accepted` instead of `InputEnded`) and the two
parameterized path-entry scenarios. The repaired assertions therefore still
fail when a required warning is omitted or a refused target becomes acceptable.

This record is committed after the validation above, so its own commit hash is
recorded in the ticket tracker rather than here. The repair changes tests and
this document only; no production file changed.
