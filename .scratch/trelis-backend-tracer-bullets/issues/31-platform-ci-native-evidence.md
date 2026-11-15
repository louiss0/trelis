# 31: Execute the cross-platform automated and native matrix

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Establish fresh supported-platform evidence for the complete migrated backend without requiring physical Linux/macOS access.

**Blocked by:**
- [30: Complete compatibility checks and retire migrated legacy paths](30-compatibility-and-contract.md)

**Status:** resolved

## Comments

GitHub publication authorized by user (public): https://github.com/louiss0/trelis. Integration now tracks origin. First real matrix run `43613401966` exposed zero PTY geometry and POSIX link misclassification; repairs merged at `69a9bdd`. Run `43613610430`: Windows and Ubuntu Dart suites passed, Windows native passed; POSIX native failed (Ubuntu external SIGINT exits -2; macOS terminal local flags differ after restoration). macOS Dart aborted on unsupported NSNumberFormatter `negativeSign`; Apple documents `minusSign`, fixed at `29a7286`, pushed for a fresh run. No POSIX/native or complete all-platform acceptance is claimed. GUI skill restoration and final review remain pending.

Partial local evidence merged as `ad0ae2d`, harness revision `23aff9b`: 926 tests, analysis, repository formatting and documentation links passed; 17 Windows TextInput scenarios and six multiline ConPTY cases passed (see `doc/evidence/trelis-backend/31-platform-evidence.md` for individual reruns and limits). **Superseded:** the "no Git remotes" statement in this comment is stale — `origin` is `github.com:louiss0/trelis.git`, and `gh auth status` reports a logged-in account. The cross-platform matrix has since been executed; see the next comment.

Cross-platform matrix executed and merged. The three failures of run `43614138132` at integration `29a7286` were reproduced from their logs and repaired on `ticket/backend-31-platform-evidence` (tip `c816001`): `65a7940` reads the macOS negative sign placement from the `negativePrefix`/`negativeSuffix` affixes (the Decimal style reports the *positive* shape as `negativeFormat`, so every runner convention was previously discarded), `848b403` excludes only Darwin's kernel-owned `PENDIN` local flag from the restoration comparison (xnu `bsd/kern/tty.c` ORs it in on any `tcsetattr` that re-enables `ICANON`, so userland cannot clear it; the exclusion is `sys.platform != 'darwin'`-guarded and no other flag is tolerated), and `76da878` gives each launched command its own process group, interrupts the group after the echoed draft proves the reader is live, requires the application's own printed result, and stops the whole group in `finally`. Verified independently with `gh`: run `43619157387` at `22d016f` and run `43619738778` at `c816001` both completed `success` on all six jobs — three Dart jobs (Windows, Ubuntu, macOS) `927` tests each plus `Formatted 150 files (0 changed)`, `No issues found!`, `Checked 155 relative links in 55 Markdown files.`; both POSIX jobs (`macos-26-arm64`, `ubuntu-26.04`) print all ten PTY scenarios `PASS`, including `signal: PASS (interrupt)`; and the Windows native job prints 17 TextInput scenarios plus six ConPTY cases `PASS`. Merged as `3475f2b` (`merge(terminal): integrate verified platform repairs`).

Final backend review fixes merged on top as `07da9ba` (`merge(terminal): integrate final review fixes`, from `8351d26`): colour applied after wrapping, error-role validation, one display escaping policy, retired feedback not replayed, a real reference-counted standalone-feedback claim, and guarded `terminalSgr`/`terminalStyledText`. Local validation on the merged tree: `dart format` 150 files unchanged, `dart analyze` no issues, `dart run tool/check_doc_links.dart` 158 links in 61 files, `dart test --reporter expanded` **937 passed**. The two failures truncated out of one early review-branch run remain unexplained in `.scratch`/`doc/evidence/trelis-backend/final-review-fixes.md`; every complete run since passed and no recurrence has been observed.

Merged revision `07da9ba` is pushed to `integration/trelis-backend-tracer-bullets` and fast-forwarded `main` (no force). Fresh confirmation runs `43623409875` (integration) and `43623409948` (main) were triggered by that push and both later completed `success` on all six jobs: the three Dart jobs reported `937` tests passed with `Formatted 150 files (0 changed)`, `No issues found!` and `Checked 158 relative links in 56 Markdown files.`, both POSIX jobs passed all ten PTY scenarios, and the Windows native job passed its 17 scenarios and six ConPTY cases. So the merge revision is green as platform evidence; it is still not final acceptance, because of the follow-ups below and because B-GUI/NVDA (ticket 32) and the ticket-33 audit are outstanding. Remaining open evidence: `test/number_input_native_checks.ps1` still fails its preference-change branch on this local Windows machine (`number input FAIL unexpected result: 1234,5` and `number input FAIL probe process did not exit` across attempts, with and without the macOS resolver change); it rewrites `HKCU:\Control Panel\International` for the run, so it is not re-run while other agents may be using the desktop and it is **not** waived. B-GUI/NVDA remains ticket 32. Status stays `claimed` pending that run and the ticket-33 revision/coverage audit.

Follow-up review (`../prompty-review/followup-review.md`) re-read the merged code and confirmed the four original fixes, but found two open defects and two minor gaps. I reproduced both defects from the merged tree; **final acceptance is not claimed** and a new fix tip is expected:

1. **Open — an important notice can be dropped during modal help.** `_deferredFeedback` is keyed by region (`lib/src/text_input.dart:647`) and `MultiSpinner` emits every task line through a single session region, so a `compile: failed` line is displaced by a later running line from another task before help returns, and compaction then only summarises it. That contradicts B-MODAL's "important notices survive modal intervals", and the sentence "important notices in full" in `doc/evidence/trelis-backend/final-review-fixes.md` overclaims; per-region replacement itself pre-dates this delta.
2. **Open — the same text has two spellings for ZWJ.** `DisplayText.from` applies `displaySafe` to a whole string while measurement applies it per grapheme cluster (`lib/src/text_measurement.dart:9-14`), and the joiner exception depends on the local string. Reproduced with a throwaway probe (deleted after use): `a\u200Db` renders as `a‍b` on the unwrapped path and as `a\u{200D}b` when wrapped (both width 10), and `a\u200Db\u200Dc` likewise. The invariant asserted by `display escaping does not depend on declared geometry` therefore holds only for the private-use code point it tests, not for joiners.
3. **Minor — `OutputProfile.copyWith` cannot clear a fact** (`lib/src/output_profile.dart`, `??` per field), and `_isAutomaticProfile` (`lib/src/text_input.dart:1080`) is still a third hand-written field list.
4. **Minor — `terminalStyledText`'s doc omits its precondition** that the text is already display-safe, so a public caller can re-create the colour-before-wrap defect it fixes.

Local numeric evidence is that `test/number_input_native_checks.ps1` stays red on this machine; it was not re-run for the follow-ups.

**Acceptance reference:** [B-PLATFORM](../../trelis-backend-implementation/spec.md#b-platform), [B-CAP](../../trelis-backend-implementation/spec.md#b-cap), [B-RESIZE](../../trelis-backend-implementation/spec.md#b-resize), [B-FAIL](../../trelis-backend-implementation/spec.md#b-fail).

- [x] Execute format, analysis, documentation and full/public Dart checks on Windows, Ubuntu and macOS CI at the target revision.
- [x] Execute real native PTY scenarios on Linux/macOS CI and Windows native/ConPTY scenarios, extending them for new profile/session/resize/failure behavior.
- [x] Record actual runner/SDK/environment, commands, results and CI artifacts; do not count configured workflows, syntax checks or old reports as execution.
- [x] Investigate unexplained failures and leave missing evidence pending instead of waiving gates through retries.
- [x] Require no physical Linux/macOS GUI or human confirmation.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Resolved by merging `ticket/backend-31-platform-evidence` at `c5876a4b83f0cdc9e6fb8d99831ad8a7e11da3dd` into `integration/trelis-backend-tracer-bullets` as no-fast-forward merge `040b6e2eb3955df110a4b4e61fd94edfac7f1321` (`merge(terminal): integrate ticket 31 platform evidence`). The branch is based on integration `07da9ba`; the merge adds the follow-up modal-notice, display-safety, profile API, Windows punctuation-fixture fixes and their evidence.

Fresh merger-local verification on Windows ran the focused public checks at the merge revision: `dart test test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/text_input_test.dart test/text_measurement_test.dart test/output_profile_text_input_test.dart test/text_input_colour_rendering_test.dart test/number_input_test.dart test/formatted_values_migration_test.dart --reporter expanded` passed 94 tests. `dart format --output=none --set-exit-if-changed .` reported 150 files unchanged; `dart analyze` reported no issues; and `dart run tool/check_doc_links.dart` checked 158 relative links in 61 Markdown files.

The branch's recorded full local Windows evidence is `dart test --reporter expanded`, 946 passing tests, plus the guarded `test/number_input_native_checks.ps1` rich, linear, and preference-change PASS cases. The fresh six-job CI run [43644894551](https://github.com/louiss0/trelis/actions/runs/43644894551) passed at code revision `b8013e6`: Windows, Ubuntu, and macOS Dart jobs each reported 946 tests, formatting, analysis, and documentation-link success; both Linux/macOS PTY jobs passed all ten scenarios including interruption and restoration; Windows native passed 17 TextInput lifecycle scenarios and six ConPTY cases. It used pinned Dart 3.13.2. `c5876a4` only updates evidence documentation after that run, and this merge reran focused checks rather than the full suite or CI.

Limitations remain explicitly recorded in `doc/evidence/trelis-backend/31-platform-evidence.md`: CI runners rather than physical Linux/macOS or human GUI confirmation; POSIX coverage is the shared public PTY harness rather than every component wrapper; Windows native is injected console records/pseudoconsole, not keyboard, clipboard, IME, rendering, or NVDA. Visible GUI/NVDA evidence and the separate final evidence-gate audit remain tickets 32 and 33, not blockers for this platform CI/native evidence ticket.

## Comments

Post-review re-verification, `ticket/backend-post-review-fixes` at
`324e3d7`: the native terminal I/O path gained a reachable idle-resize
observation (`lib/src/native_resize.dart`), so both platform stages gained a
scenario. The Windows stage now runs `resize` as its eighteenth public TextInput
scenario: it shrinks the real console buffer from 120x30 to 40x20 with no key
injected and requires the draft row to be rewrapped inside the new width before
submitting. The POSIX stage now runs an eleventh PTY scenario: it resizes the
pseudo-terminal to 30 columns, delivers the window change, and only proceeds
once the overflow marker proves the idle prompt reflowed. Formatting (154
files), analysis, the documentation-link check, the full suite (961 tests) and a
fresh six-job matrix were re-run at that revision; the detailed results are in
[the post-review record](../../../doc/evidence/trelis-backend/post-review-fixes.md)
and [the acceptance audit](../../../doc/evidence/trelis-backend/backend-acceptance.md).
The ticket's own verdict and limitations are unchanged.