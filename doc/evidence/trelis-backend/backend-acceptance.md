# Backend acceptance audit — ticket 33

**Verdict: BLOCKED.**

This is a gate decision, not an implementation result or a release-wide
accessibility claim. Named-theme integration remains blocked. The fresh
all-platform/native matrix passed at this candidate, and the two defects that
blocked the previous audit are repaired and visible in readable artifacts, but
B-GUI still has no artifact at this revision for two named checkpoints
(narrow/idle resize and ASCII/no-colour fallback) and only historical captures
for a third (cleanup/repeated sessions). B-GATE therefore cannot open.

## Audit history (preserved)

| Revision | Verdict | What it rested on |
| --- | --- | --- |
| `135043d615392d3190eaf5f272dd6317485dd0a7` | blocked | The ticket-32 report was unreadable (double-mojibaked), its own embedded verdict said blocked, and no artifact showed caret-preserving editing under concurrent feedback. |
| `6bb265d9cc947bb854921508c4e8ddc33462af65` (this audit) | blocked | The concurrent-editor and modal-help defects are repaired and verified from readable screenshots 11–17. The remaining blocker is narrower and is recorded below. |

The earlier verdict is superseded, not erased. Neither audit treats a resolved
tracker state, a planned check or a configured workflow as a pass, and neither
opens theme integration.

## Candidate revision and audit environment

- **Candidate source revision:**
  `6bb265d9cc947bb854921508c4e8ddc33462af65`
  (`merge(backend-gate): integrate strengthened ticket 32 evidence`, the local
  integration tip `75719dd` merged into `ticket/backend-33-evidence-gate`).
  It is a candidate only, not an accepted backend revision.
- **Code revisions contained:** `135043d`, and through the merge `7676a5f`,
  `a598c8e` (concurrent-feedback probe plus the `text_input` help/draft-row
  fix) and `e5762ad` (readable UTF-8 restatement of the ticket-32 evidence).
- **Audit environment:** Windows 11 Home `10.0.26200`, PowerShell
  `5.1.26100.9818`, Dart `3.13.2 (stable)`, `windows_x64`.
- **Computer-use provider observed for this audit:** orca `1.4.259`,
  `orca-computer-use-windows` protocol 1. `orca computer capabilities` reports
  `click, typeText, pressKey, hotkey, pasteText, scroll, drag, setValue,
  performAction` and no resize/move action, which independently corroborates
  the `moveResize: false` limitation ticket 32 recorded.
- **Profile and input for local focused checks:** deterministic `ScriptedInput`
  and `StringBuffer` public seams, plus the declared ASCII/visible profiles as
  selected by the suites; native checks use their real Windows-console or
  ConPTY wrappers. No real secret was used.
- **Backlog state inspected:** the active tracker records tickets 01–32 as
  resolved (including 31 and 32); ticket 33 remains claimed for this audit.

## Fresh platform and native evidence (B-PLATFORM)

This audit pushed the merge commit unchanged to
`ticket/backend-33-evidence-gate`, which ran the whole workflow matrix:
[run 43735431396](https://github.com/louiss0/trelis/actions/runs/43735431396)
(**success**, source `6bb265d9cc947bb854921508c4e8ddc33462af65`,
2026-11-15 UTC, six jobs). The workflow pins Dart 3.13.2.

| Job | Runner/SDK | Executed result | Artifact |
| --- | --- | --- | --- |
| Dart | `windows-latest`, `windows_x64`, Dart 3.13.2 | `Formatted 152 files (0 changed)`; `No issues found!`; `Checked 158 relative links in 58 Markdown files.`; `+949: All tests passed!` | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866137) |
| Dart | `ubuntu-latest`, `linux_x64`, Dart 3.13.2 | the same format, analysis and 158-link results; `+949: All tests passed!` | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866099) |
| Dart | `macos-latest`, `macos_arm64`, Dart 3.13.2 | the same format, analysis and 158-link results; `+949: All tests passed!` | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866114) |
| POSIX native | Ubuntu, Dart 3.13.2 | ten public PTY scenarios `PASS`: rich (`alpha`), escape (`cancel`), interrupt, signal, eof, error, repeat (`alpha,alpha`), session-retire, dumb-auto, dumb-rich (`unavailable:…`) | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866112) |
| POSIX native | macOS arm64, Dart 3.13.2 | the same ten PTY scenarios `PASS` | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866178) |
| Windows native | `windows-latest`, Dart 3.13.2 | 17 `text input <scenario> PASS` lifecycle reports and six multiline pseudoconsole cases `PASS` | [job](https://github.com/louiss0/trelis/actions/runs/43735431396/job/132876866061) |

The Windows native job actually reported the 17 scenarios this audit relies on:
`rich`, `linear-cursor`, `linear-long`, `help-text-linear`, `help-text-rich`,
`help-password-linear`, `help-password-rich`,
`help-password-interrupt-linear`, `help-text-eof-rich`, `redirected`,
`dumb-auto`, `escape`, `interrupt`, `eof`, `error`, `repeat`,
`session-retire`; and the pseudoconsole cases `framed-command`,
`typed-command`, `framed-multiline`, `editing`, `function-key`,
`application-navigation`. This satisfies the CI-only Linux/macOS requirement
and adds no physical Linux/macOS, human or local GUI checkpoint.

## Local re-verification at the candidate

| Command | Actual result |
| --- | --- |
| `dart pub get` | `Got dependencies!`; resolved `termunicode 0.2.0` with 0.3.0 reported as incompatible and therefore not taken. |
| `dart format --output=none --set-exit-if-changed .` | Passed: `Formatted 152 files (0 changed) in 2.91 seconds.` |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 158 relative links in 58 Markdown files.` |
| `dart test --reporter compact` | Passed: `+949: All tests passed!` |
| `dart test test/gui_evidence_probe_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_feedback_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/output_profile_text_input_test.dart test/text_measurement_test.dart test/password_test.dart --reporter expanded` | Passed: 67 focused tests (`+67: All tests passed!`). |
| `dart test test/gui_evidence_probe_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_feedback_test.dart test/text_measurement_test.dart --reporter compact` | Passed: 25 tests, which confirms the count the ticket-32 report claims for its own focused run. |

The affected focused suites exercise the public session/help/overflow/failure,
capability/profile, measurement, secret and GUI-probe seams. The full suite and
the matrix are stronger automated checks; neither substitutes for a visible GUI
observation.

## Ticket audit

| Ticket group | Tracker state | Audit result |
| --- | --- | --- |
| 01 baseline; 02 terminal I/O; 03 profiles; 04 native capability | resolved | Evidence records and current profile/native checks support the automated portions. |
| 05 safe rendering; 06 measurement; 07 narrow editor; 08 resize; 09 colour; 10 events; 11 help; 12 sessions | resolved | Current focused/full checks cover the public scripted seams; see their numbered reports in this directory. |
| 13 live status; 14 feedback lifecycles; 15 modal help; 16 short screen; 17 failure recovery | resolved | Current focused/full checks cover feedback/session behaviour. The visible-GUI proof is separately incomplete as recorded under B-GUI. |
| 18 private entry through 30 compatibility/contract | resolved | Component matrix, compatibility inventory, help, secret and migration evidence exist; current full suite passed. |
| 31 platform/native | resolved | **Pass at the candidate**: six-job matrix above, with the executed scenario lists. |
| 32 agent Windows GUI | resolved in tracker | **Not sufficient for B-GUI**: the concurrent-editor and modal-help parts are now acceptable; the resize/ASCII/cleanup parts are not. Tracker resolution does not override the artifact gap. |
| 33 final gate | claimed by this branch | **Blocked**; this publication does not resolve it or unblock themes. |

## Normative B requirement audit

| Requirement | Status at candidate | Evidence and limitation |
| --- | --- | --- |
| B-BASE | pass | `baseline.md`, `30-compatibility-and-contract.md`, current full suite and component matrix evidence retain the source inventory/baseline. Historical baseline failures are not counted as current passes. |
| B-CAP | pass | `ticket-03-output-profiles.md`, `ticket-04-native-capabilities.md`, `output_profile_text_input_test.dart`, and the fresh native matrix. Synthetic profiles declare geometry; redirected/dumb restrictions are exercised. |
| B-MEASURE | pass | `06-unicode-text-input-mapping.md`, the pinned `termunicode: 0.2.0` dependency, `text_measurement_test.dart`, and the full suite. This is not a universal terminal/font-width claim. |
| B-RENDER | pass | `05-safe-typed-text-input.md`, `09-text-input-colour-rendering.md`, presentation safety and colour suites. |
| B-EVENT | pass | `ticket-10-linear-events.md`, session/feedback suites and the full suite. |
| B-SESSION | pass | `ticket-12-scoped-session.md`, session suites and the fresh native matrix. |
| B-FEEDBACK | pass | `13-prompt-live-status.md`, `14-multiple-feedback-lifecycles.md`, and current modal/short-screen/failure suites. |
| B-PARITY | pass | `30-compatibility-and-contract.md`, `component_acceptance_matrix_test.dart`, the public compatibility inventory and the current 949-test suite. |
| B-HELP | pass | `11-text-input-help.md`, `30-compatibility-and-contract.md`, and current help/modal suites, including the new paragraph-break and draft-row assertions. |
| B-SECRET | pass for automated and recorded visible non-disclosure | `18-private-entry-migration.md`, `password_test.dart`, and screenshots [16](gui/16-secret-actions.png) and [17](gui/17-final-accepted.png): the synthetic canary never appears in the transcript and only outcome metadata is printed. No general redaction or accessibility claim is made. |
| B-RESIZE | pass for scripted/native evidence | `08-idle-text-input-resize.md`, `16-short-screen-overflow.md`, focused suites and CI. No visible resize checkpoint exists at this revision; see B-GUI. |
| B-MODAL | pass for scripted/native evidence | `15-modal-help-live-jobs.md`, the modal-help suite and CI, plus the visible help/dismissal capture described below. |
| B-FAIL | pass | `17-session-failure-recovery.md`, current failure suite and native session-retire checks. Forcible process termination/external mutation remains outside the contract. |
| B-COMPAT | pass | `30-compatibility-and-contract.md`, public inventory and current full suite. |
| B-PLATFORM | pass | Fresh matrix run 43735431396, detailed above. |
| B-GUI | **blocked** | Editing/caret under concurrent writes, help/dismissal and secret non-disclosure are observed and correct; narrow/idle resize and ASCII/no-colour fallback have no artifact at this revision, and cleanup/repeated sessions remain historical. |
| B-GATE | **blocked** | A required B-GUI sub-gate is blocked, so no accepted source revision exists. |

## B-GUI artifact audit

The repaired report [32-agent-windows-gui.md](32-agent-windows-gui.md) is now
readable UTF-8 and records revision `a598c8e`, Windows Terminal window
`prompty-ticket32-probe`, orca `1.4.259`, synthetic `press-key`/`hotkey`/
`type-text` input, and the NVDA absence in
[gui/environment.txt](gui/environment.txt)
(`nvda-command=; nvda-process-count=0`).

**Observed and accepted.** Each of these was inspected rather than taken from
the prose:

- [11-live-feedback-draft.png](gui/11-live-feedback-draft.png): live prompt
  `> alpha` with `[status]` informational and spinner writes streaming above it
  (through `#79`/`79` in this frame).
- [12-caret-moved.png](gui/12-caret-moved.png): the same draft after
  `Left`,`Left`. The still frame does not show a caret, so this frame alone does
  not evidence caret movement; the report says so instead of overclaiming, and
  the edit that follows is what makes the checkpoint checkable.
- [13-caret-edit.png](gui/13-caret-edit.png): `> alpXha` after `X`, i.e. the
  insertion landed between `alp` and `ha` while concurrent writes continued.
- [14-modal-help.png](gui/14-modal-help.png): help owns its own rows,
  `Validation: An empty value is allowed.` ends the first paragraph, the two
  `supplementaryHelp` entries appear as separate display lines, no literal
  `\u{000A}` appears, and the draft row is absent while help is open.
- [15-help-dismissed.png](gui/15-help-dismissed.png): `> alpXha` repainted once
  after `Escape`, with no stale draft row and no concatenated help text.
- [16-secret-actions.png](gui/16-secret-actions.png): the `Synthetic canary`
  prompt with `Hidden entry; Enter opens actions.`; no secret text is echoed.
- [17-final-accepted.png](gui/17-final-accepted.png): `Indexing visible GUI
  evidence: completed`, `Background activity: completed` and
  `GUI-PROBE:accepted:alpXha;secret:accepted` after 297 concurrent writes.

This is enough to close the two defects that blocked the earlier audit: the
draft and caret survive concurrent `Text`/`Spinner`/`Progress` writes, and
session-owned help no longer writes from the live draft row or leak a literal
`\u{000A}`. The same interleaving is driven deterministically by
`runGuiEvidenceProbe(pulses: …)` in `test/gui_evidence_probe_test.dart`, which
asserts the caret-relative transcript order, the pulse counts, the help line
breaks, the absence of `\u{000A}` and the absence of the synthetic canary. That
test is automation and is not counted as the GUI observation.

**Still missing, and why the gate stays blocked.**

1. *Narrow/idle resize.* No capture exists in the tree at this revision. The
   repair deleted `02-narrow-modal-help.png`, which was the only narrow-window
   capture and which additionally showed the pre-fix breakage (`Bas s;`,
   truncated control line) that `429526b` fixed. The provider exposes no resize
   action, so this checkpoint cannot be recreated with the installed
   computer-use tooling alone.
2. *ASCII/no-colour fallback.* No capture exists in the tree at this revision.
   The repair deleted `05-ascii.png`, the only visible ASCII/no-colour capture,
   and `tool/gui_evidence_probe.dart --ascii` was not re-run in the visible
   window even though the harness supports it.
3. Both deletions matter for B-GATE rather than merely for tidiness: `429526b`
   rewrote `_wrapText` paragraph handling and added the draft-row clear, so
   every wrapped/paragraph-bearing visible capture predating it is *affected
   evidence*. Stale successful captures cannot be carried forward to a newer
   backend, and the deleted captures are exactly the ones that carried the
   narrow and ASCII checkpoints.
4. *Cleanup/repeated sessions* are present but historical: the report states
   `06`–`10` were captured at `7676a5f` and not re-run at `a598c8e`. Their
   contents, inspected here, are:
   [06](gui/06-rich-feedback-profile.png) the superseded `7676a5f` state — help
   concatenated onto `> alpha` with a literal `\u{000A}`, i.e. the defect that
   `14`/`15` now fix, so it must not be read as current rendering;
   [07](gui/07-repeat-cleanup.png) two sequential prompts producing
   `alpha,alpha`; [08](gui/08-error-recovery.png) an optional `Failure` prompt
   submitted empty followed by a second prompt, which does **not** visibly show
   a validation error despite the file name;
   [09](gui/09-cancel-cleanup.png) `cancel`; and
   [10](gui/10-interrupt-cleanup.png) `interrupt`.
5. *Inventory wording.* The report's screenshot inventory calls `16` the
   "password action chooser"; the frame shows the hidden-entry prompt and its
   action cue, not the chooser list. It is a small overstatement in an otherwise
   honest report and is recorded rather than silently corrected here.

## Required follow-up to unblock B-GATE

1. Capture a visible `dart run tool/gui_evidence_probe.dart --ascii` run at the
   candidate revision with its own expected-versus-observed note.
2. Capture a narrow-window prompt and modal-help checkpoint. Because the
   installed provider cannot resize, this needs a launcher that fixes the window
   size, or a provider that can resize; it is a tooling limitation to state, not
   a human checkpoint to add.
3. Either re-capture the repeated/error/cancel/interruption cleanups at the
   candidate or state plainly that they are historical and excluded from the
   current pass.
4. Correct the `16` description and the `06`–`10` inventory entries so no
   reader takes a superseded defect for current rendering.

## Limitations carried forward

- Linux/macOS evidence is CI runner/PTY evidence only, as required. It is not
  physical-machine or GUI verification, and it does not need to be.
- Windows native checks inject console records/use a pseudoconsole. They do not
  prove real keyboard, clipboard, IME, font rendering, screen-reader or human
  usability behaviour.
- Agent-generated synthetic input is unverified by the provider; the screenshots
  are the evidence, and no claim is made about how a screen reader or a human
  would perceive them. NVDA was recorded absent, so there is no speech evidence
  and no accessibility qualification.
- Unicode measurement states a supported cluster/width policy; terminal and font
  behaviour beyond that policy is not universally asserted.
- The report neither waives the local historical number-input preference probe
  history nor promotes old configured workflows, planned coverage, or a
  screenshot without the necessary scenario record into a pass.
- The retained legacy backend gate is deliberately unchanged. Its required
  mirror is only permitted after an actually accepted verdict; mirroring now
  would falsely resolve superseded layered work.
- This audit was published at a documentation-only commit on
  `ticket/backend-33-evidence-gate`. The matrix cited above ran at the code
  revision `6bb265d`, which that commit does not change.
