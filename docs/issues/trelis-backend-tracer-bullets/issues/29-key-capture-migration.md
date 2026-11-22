# 29: Migrate Keypress and KeyChordInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Capture or declare gestures and sequences without help intercepting answer data or falsifying provenance.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret).

- [x] Preserve observed/declared/ambiguous provenance, observation requirements and explicit sequence completion.
- [x] Keep reserved cancellation/interruption and capture back-out semantics; no universal help gesture steals a candidate.
- [x] Provide safe help before/after raw capture and truthful stage-specific action guidance.
- [x] Retain removal/clear/declaration/review and supplied-answer compatibility.
- [x] Exercise actual public rich/linear, unavailable capture and terminal outcomes with shared feedback and synthetic gestures.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-29-key-capture-migration` in commits `9ce9846`
(output profiles, terminal leases, shared sessions and help), `6e71495` (public
behavior tests), `03259be` (README) and `e3648e8` (evidence), based on
integration `9d6ecbe`. Merging the latest integration tip into the branch was a
no-op ("Already up to date"); that tip was unchanged when this report was
written, and ticket 17's shared-writer failure handling is intact — the session
failure suite asserts that a failed shared writer still surfaces the original
failure, retires the session and rejects a late registration. Merging this
branch into integration is deliberately left to the parent.

`Keypress` and `KeyChordInput` now accept `terminal`, `outputProfile` and
`session`. They resolve the invocation/source/legacy output-profile precedence,
constrain the profile to observed geometry, apply `NO_COLOR`, refuse an
explicitly requested rich mode the effective profile cannot support before
painting anything, and select rich only in `automatic` mode when the profile
permits rich interaction. A `TerminalIo` adapter is leased and restored exactly
once and cannot be combined with `source:`/`output:`. An attached prompt
inherits its session's input, output, mode and profile, reuses the session-owned
reader and writer, rejects competing invocation configuration, and forwards the
native capture control so Windows virtual-key observation keeps working inside a
session.

Provenance is unchanged and now observable: declarations stay `declared` with
their spelling and unverified warning, legacy byte-stream captures stay
`ambiguous`, and console key records report `observed` virtual-key letters and
modifier state. The console record path is no longer restricted to the native
adapter, so a scripted replay of `ESC [ 901 ; vk ; code ; state ~` exercises
observation without claiming a physical keyboard; a key that no vocabulary
represents reports `Gesture unavailable.` instead of inventing a gesture.
`requireObservation` still rejects declarations and mixed reviews until only
observed gestures remain.

Rich `Ctrl+T` and linear `/help` now carry component help: observed versus
declared or ambiguous provenance, the reserved Escape/Ctrl+C gestures, the
observation requirement, the declaration vocabulary and explicit sequence
completion. Help is reachable before and after a capture and is deliberately not
reachable while capture is armed, because the next key is the candidate gesture;
the action line states that in each mode. Escape dismisses help and restores the
focused action line, Escape backs out of armed capture without cancelling the
prompt, and session help retains background feedback updates until dismissal
restores the latest composite. Declaration entry has its own help and Escape
back-out. Removal, clearing, review, `/done`/Enter completion and supplied-answer
declaration parsing are unchanged.

Verification on Windows 10 Home 25H2 (`10.0.26200.0`, `windows_x64`) with Dart
SDK 3.13.2: `dart format --output=none --set-exit-if-changed` on the three
changed source/test files reported `Formatted 3 files (0 changed)`; `dart
analyze` reported no issues; the new `test/key_capture_test.dart` (30 tests)
passed; that file with the component acceptance matrix and the session
feedback, modal-help and failure-recovery suites passed 190 tests; `dart run
tool/check_doc_links.dart` checked 152 links in 43 files; and the full suite
passed 726 tests. Code and tests are at revision `03259be`; the final pass was
repeated at the branch tip `e3648e8`, which changes this record only. Evidence,
source revision, environment, commands, expected/actual results and limitations
are recorded in
`assets/evidence/trelis-backend/29-key-capture-migration.md`.

Limitations: this is scripted public-behavior evidence only. Native
`key_capture_windows.ps1`/`key_capture_native_app.dart` capture, PTY,
Linux/macOS CI, visible-terminal GUI/NVDA, alternate-screen modal help,
short-screen feedback compaction for this family and the final evidence gate
remain outstanding. Key spelling remains source-dependent and is not
normalized. A lone trailing Escape on a session-owned reader reports
`InputEnded` because the shared key parser only flushes a pending Escape for a
prompt-owned reader. Key capture has no live editable region, so it registers no
session repaint and its feedback is not compacted on short screens. No palette
or instruction-display argument was added because the component paints no styled
projection. One shared line changed in `lib/src/text_input.dart` (a flow that
supplies `linearHelpText` now keeps it when it also advertises exact commands;
flows without it are unchanged) and `_promptRunner` gained an optional capture
control; both overlap regions other migrations restructured, and three unrelated
test files already failed the repository-wide format check on the integration
tip.

## Comments

**Combined integration merge.** Merged branch tip `e3648e8` as `39d85fe`. The shared linear-help conflict retained integration's component help plus exact-command guidance, while preserving capture forwarding. At combined revision `74c5171`, 275 targeted tests and 813 full-suite tests passed; `dart analyze` reported no issues, changed-Dart formatting reported 8 files / 0 changed, and the doc-link check reported 153 links in 54 files. Native/GUI/cross-platform limitations remain as documented.
