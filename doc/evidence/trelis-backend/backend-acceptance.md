# Backend acceptance audit — ticket 33

**Verdict: BLOCKED.**

This is a gate decision, not an implementation result or a release-wide
accessibility claim. Named-theme integration remains blocked. The required
fresh all-platform/native matrix passed, but the available Windows
agent-operated GUI evidence is not sufficient to accept B-GUI; therefore it
cannot open B-GATE.

## Candidate revision and audit environment

- **Candidate source revision:**
  `135043d615392d3190eaf5f272dd6317485dd0a7`
  (`merge(gui): integrate ticket 32 Windows GUI evidence`). This is the local
  integration tip from which `ticket/backend-33-evidence-gate` was created.
  It is a candidate only, not an accepted backend revision.
- **Audit environment:** Windows 11 `10.0.26200.0`, PowerShell `5.1.26100.9818`,
  Dart `3.13.2 (stable)`, `windows_x64`.
- **Profile and input for local focused checks:** deterministic `ScriptedInput`
  and `StringBuffer` public seams, declared rich/ASCII profiles as selected by
  the suites; native checks use their real Windows-console or ConPTY wrappers.
  No real secret was used.
- **Backlog state inspected:** the active tracker records tickets 01–32 as
  resolved (including 31 and 32); ticket 33 was claimed for this audit. A
  resolved tracker state is not promoted to a gate pass without the evidence
  below.

The source candidate contains the platform evidence revision `c5876a4` and the
follow-up test/code revision `b8013e6` as ancestors. The evidence references
below remain useful historical public-behaviour evidence, while this audit's
local checks and CI matrix are at the candidate revision.

## Fresh platform and native evidence (B-PLATFORM)

The audit pushed the candidate unchanged to
`ticket/backend-33-evidence-gate`, which triggered the final workflow matrix:
[run 43649574554](https://github.com/louiss0/trelis/actions/runs/43649574554)
(**success**, source `135043d615392d3190eaf5f272dd6317485dd0a7`,
2026-11-14 UTC). The workflow pins Dart 3.13.2.

| Job | Runner/SDK | Executed result | Artifact |
| --- | --- | --- | --- |
| Dart | `windows-latest`, `windows_x64`, Dart 3.13.2 | format: 152 unchanged; analysis clean; 158 links; 947 tests | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614810027) |
| Dart | `ubuntu-latest`, `linux_x64`, Dart 3.13.2 | format, analysis, links and 947 tests passed | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614810042) |
| Dart | `macos-latest`, `macos_arm64`, Dart 3.13.2 | format, analysis, links and 947 tests passed | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614810048) |
| POSIX native | Ubuntu, Dart 3.13.2 | ten public PTY scenarios passed: rich, escape, interrupt, signal, EOF, error, repeat, session-retire, dumb-auto and dumb-rich | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614809966) |
| POSIX native | macOS arm64, Dart 3.13.2 | the same ten PTY scenarios passed | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614809787) |
| Windows native | `windows-latest`, Dart 3.13.2 | 17 TextInput lifecycle scenarios and six multiline ConPTY cases passed | [job](https://github.com/louiss0/trelis/actions/runs/43649574554/job/132614810013) |

This satisfies the CI-only Linux/macOS requirement. It does not add a physical
Linux/macOS, human, or local GUI checkpoint.

## Local re-verification at the candidate

| Command | Actual result |
| --- | --- |
| `dart pub get` | Passed; resolved dependencies and retained `termunicode 0.2.0`. |
| `dart format --output=none --set-exit-if-changed .` | Passed: `Formatted 152 files (0 changed)`. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 158 relative links in 57 Markdown files.` |
| `dart test --reporter expanded` | Passed: 947 tests. |
| `dart test test/gui_evidence_probe_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/output_profile_text_input_test.dart test/text_measurement_test.dart test/password_test.dart --reporter expanded` | Passed: 56 focused tests. |
| 17 scenarios from `test/text_input_windows.ps1`, followed by `test/multiline_conpty_windows.ps1` | Passed: 17 TextInput native scenarios and six ConPTY cases. The reports are local temporary artifacts and are not treated as GUI evidence. |
| `git diff --check` before documentation edits | Passed: no whitespace errors. |

The affected focused suites exercise the public session/help/overflow/failure,
capability/profile, measurement, secret and GUI-probe seams. The full suite and
CI are stronger automated checks; neither substitutes for a visible GUI
observation.

## Ticket audit

| Ticket group | Tracker state | Audit result |
| --- | --- | --- |
| 01 baseline; 02 terminal I/O; 03 profiles; 04 native capability | resolved | Evidence records and current profile/native checks support the automated portions. |
| 05 safe rendering; 06 measurement; 07 narrow editor; 08 resize; 09 colour; 10 events; 11 help; 12 sessions | resolved | Current focused/full checks cover the public scripted seams; see their numbered reports in this directory. |
| 13 live status; 14 feedback lifecycles; 15 modal help; 16 short screen; 17 failure recovery | resolved | Current focused/full checks cover feedback/session behaviour. The visible-GUI proof remains separately inadequate. |
| 18 private entry through 30 compatibility/contract | resolved | Component matrix, compatibility inventory, help, secret and migration evidence exist; current full suite passed. |
| 31 platform/native | resolved | **Pass at the candidate**: final six-job CI matrix above and the local Windows native rerun. |
| 32 agent Windows GUI | resolved in tracker | **Not acceptable for B-GUI** for the reasons below. Tracker resolution does not override the contradictory/insufficient artifact. |
| 33 final gate | claimed by this branch | **Blocked**; publication does not resolve it or unblock themes. |

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
| B-PARITY | pass | `30-compatibility-and-contract.md`, `component_acceptance_matrix_test.dart`, the public compatibility inventory and the current 947-test suite. |
| B-HELP | pass | `11-text-input-help.md`, `30-compatibility-and-contract.md`, and current help/modal suites. |
| B-SECRET | pass for automated and recorded visual non-disclosure | `18-private-entry-migration.md`, `password_test.dart`, and the synthetic-canary GUI artifact. No general redaction or accessibility claim is made. |
| B-RESIZE | pass for scripted/native evidence | `08-idle-text-input-resize.md`, `16-short-screen-overflow.md`, focused suites and CI. The GUI artifact includes a resize checkpoint but does not make the GUI gate pass. |
| B-MODAL | pass for scripted/native evidence | `15-modal-help-live-jobs.md`, current modal-help suite and CI. |
| B-FAIL | pass | `17-session-failure-recovery.md`, current failure suite and native session-retire checks. Forcible process termination/external mutation remains outside the contract. |
| B-COMPAT | pass | `30-compatibility-and-contract.md`, public inventory and current full suite. |
| B-PLATFORM | pass | Fresh matrix run 43649574554, detailed above. |
| B-GUI | **blocked** | The available artifacts do not establish all required visible Windows scenarios at the candidate revision; details below. |
| B-GATE | **blocked** | A required B-GUI sub-gate is blocked, so no accepted source revision exists. |

## B-GUI blocker and artifact audit

Ticket 32 contributes these checked-in artifacts:

- `doc/evidence/trelis-backend/gui/01-modal-help.png` through
  `05-ascii.png`: an initial agent-visible Windows Terminal probe at source
  `07da9ba`, including help, narrow resize, a synthetic secret result, caret
  edit and ASCII/no-colour fallback.
- `06-rich-feedback-profile.png`: later visible output with feedback and help.
- `07-repeat-cleanup.png`, `08-error-recovery.png`, `09-cancel-cleanup.png`
  and `10-interrupt-cleanup.png`: visible terminal captures of cleanup-related
  scenarios.
- `test/gui_evidence_probe_test.dart`: a current deterministic probe test,
  which passed locally and in the 947-test matrix but is not a GUI substitute.

The companion GUI report at
`doc/evidence/trelis-backend/32-agent-windows-gui.md` is malformed on disk
(double-mojibaked UTF-16 content). Recovering its text for inspection yields
its own explicit `Verdict: blocked, not accepted` and says the initial visible
probe failed to show that concurrent feedback preserves a usable editor; it
also says repeated/error/cancel/interruption observations were not completed
there. Later commits add screenshots and mark ticket 32 resolved, but do not
supply a readable, revision-specific expected-versus-observed record that
supersedes that verdict.

More importantly, `06-rich-feedback-profile.png` visibly shows repeated
background status writes before and after the `> alpha` prompt. It shows a
post-help accepted result, but it does not show editing/caret preservation
while those concurrent writes occur. The initial caret screenshot predates the
later profile/screenshot work, and the cleanup screenshots do not fill that
concurrent-editor checkpoint. This is insufficient evidence for B-GUI's
required combination of keyboard editing/caret movement with concurrent
feedback/informational writes at one candidate revision.

The ticket also records NVDA as absent (`Get-Command nvda` found no command and
`Get-Process nvda` found no process). That absence is correctly not treated as
a failure requiring a human check, but there is no speech evidence and no
accessibility qualification. Agent-generated synthetic input remains
automation, not physical-keyboard or human-usability evidence.

To unblock the gate, ticket 32 needs a readable replacement report and a fresh
agent-operated visible-terminal capture at the chosen revision that records
expected versus observed results for all B-GUI checkpoints, especially editing
and caret movement while feedback/informational writes occur, plus the already
listed help/dismissal, resize, ASCII/no-colour, synthetic-secret and cleanup
scenarios. It must retain the NVDA availability/absence observation and make no
human or whole-library accessibility claim.

## Limitations carried forward

- Linux/macOS evidence is CI runner/PTY evidence only, as required. It is not
  physical-machine or GUI verification, and it does not need to be.
- Windows native checks inject console records/use a pseudoconsole. They do not
  prove real keyboard, clipboard, IME, font rendering, screen-reader or human
  usability behaviour.
- Unicode measurement states a supported cluster/width policy; terminal and
  font behaviour beyond that policy is not universally asserted.
- The report neither waives the local historical number-input preference probe
  history nor promotes old configured workflows, planned coverage, or a
  screenshot without the necessary scenario record into a pass.
- The retained legacy backend gate is deliberately unchanged. Its required
  mirror is only permitted after an actually accepted verdict; mirroring now
  would falsely resolve superseded work.
