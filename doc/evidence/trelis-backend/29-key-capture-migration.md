# Ticket 29 — key capture migration evidence

**Status:** pass for the scripted public key-capture seam.

## Source and environment

- **Implementation revision:** `03259be` (`feat`/`test`/`docs` commits on
  `ticket/backend-29-key-capture-migration`), based on integration `9d6ecbe`.
  This record's own commit changes documentation only.
- **Branch:** `ticket/backend-29-key-capture-migration`
- **Date:** 2026-11-13
- **Environment:** Windows 10 Home 25H2, build `10.0.26200.0`
  (`windows_x64`), Dart SDK 3.13.2 stable
- **Input/output:** synthetic `Stream<String>` input and `StringBuffer` output,
  plus a public `TerminalIo` fake that records acquisition and restoration
- **Rich profile:** explicitly declared cursor support and 80×24 geometry;
  linear scenarios declare no geometry

## Public behavior exercised

`test/key_capture_test.dart` invokes `Keypress` and `KeyChordInput` only through
public constructors and `prompt`. It verifies that:

- observed, declared and ambiguous provenance survive rich captures, linear
  declarations, supplied answers and mixed reviews; a synthetic replay of the
  console key record (`ESC [ 901 ; vk ; code ; state ~`) reports observed
  virtual-key letters and modifier state, while a legacy byte stream stays
  ambiguous;
- `requireObservation` rejects declarations, rejects mixed reviews until only
  observations remain, and never silently upgrades provenance;
- Escape backs out of armed capture and returns to review, Ctrl+C interrupts,
  neither reserved gesture can be captured live, and an unrepresentable key
  reports `Gesture unavailable.` with an unchanged `Review: empty`;
- rich `Ctrl+T` help and linear `/help` describe the workflow, provenance,
  reserved gestures and observation requirement; Escape dismisses help and
  restores the focused action line; while capture is armed the next key is a
  candidate, so help is not reachable and the action line says so;
- declaration entry has its own help and Escape back-out; removal, clearing,
  review and explicit `/done`/Enter completion remain unchanged;
- supplied answers still map to declarations, reject invalid key names, and
  reject observation-required declarations;
- explicit rich mode without declared cursor support and positive geometry
  returns `Unavailable` and paints nothing; an `automatic` source chooses rich
  only when the effective profile supports it;
- a `TerminalIo` adapter is leased and restored exactly once, cannot be combined
  with `source:` or `output:`, and a session-attached prompt rejects competing
  invocation configuration;
- an explicit `TerminalSession` shares its reader and writer, keeps a live
  `Spinner` update and its review, and session help retains background feedback
  updates until dismissal restores the latest composite.

`test/component_acceptance_matrix_test.dart` supplies public rich and linear key
capture tasks. `test/terminal_session_feedback_test.dart`,
`test/terminal_session_modal_help_test.dart` and
`test/terminal_session_failure_recovery_test.dart` exercise the shared session,
modal-help and failure-recovery behavior this prompt attaches to; the failure
suite confirms a failed shared writer still surfaces the original failure,
retires the session and rejects a late registration.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/key_capture.dart lib/src/text_input.dart test/key_capture_test.dart` | Passed: `Formatted 3 files (0 changed)` |
| `dart analyze` | Passed: `No issues found!` |
| `dart test test/key_capture_test.dart --reporter expanded` | Passed: 30 tests |
| `dart test test/key_capture_test.dart test/component_acceptance_matrix_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_failure_recovery_test.dart --reporter compact` | Passed: 190 tests |
| `dart test --reporter compact` | Passed: 726 tests |
| `dart run tool/check_doc_links.dart` | Passed: 152 relative links in 43 Markdown files |

## Limitations

This record is deterministic scripted public-behavior evidence at the listed
implementation revision. It is not native Windows-console capture, PTY,
visible-terminal GUI/NVDA, Linux/macOS CI, resize/short-screen, alternate-screen
modal help or final backend-gate evidence; those remain owned by their dedicated
tickets and the final evidence gate. `test/key_capture_windows.ps1` and
`test/key_capture_native_app.dart` were not executed here, so the native
virtual-key and modifier observation path is covered by synthetic replay only.

Key spelling stays source-dependent; equal keys from different sources are not
normalized. A lone trailing Escape on a session-owned reader reports
`InputEnded` rather than cancellation because the shared key parser only flushes
a pending Escape for a prompt-owned reader. Key capture has no live editable
region, so it registers no session repaint and session feedback is not compacted
for short screens. Command history is not recorded for key capture. No palette
or instruction-display argument was added because the component paints no styled
projection. Three unrelated test files already failed the repository-wide format
check on the integration tip and were not touched.
