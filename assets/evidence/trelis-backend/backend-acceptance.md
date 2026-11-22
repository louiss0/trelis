# Backend acceptance audit — ticket 33

**Verdict: ACCEPTED.**

This is a gate decision at one backend source revision, not an implementation
result and not a release-wide accessibility claim. Every normative B requirement
has an executed check and an artifact pointer below; every active tracker ticket
01–32 is resolved with evidence that was re-run or re-captured at this code
revision; the retained limitations are stated rather than waived. Named-theme
integration is therefore unblocked as a *separate* handoff, which this audit
does not start.

A post-review round then changed the native terminal I/O path to make the idle
resize seam reachable, so this audit was re-run at that revision and the verdict
re-affirmed. Every finding of that review, including the two evidence corrections
below, has a disposition in
[post-review-fixes.md](post-review-fixes.md).

## Audit history (preserved)

| Revision | Verdict | What it rested on |
| --- | --- | --- |
| `135043d615392d3190eaf5f272dd6317485dd0a7` | blocked | The ticket-32 report was unreadable (double-mojibaked), its own embedded verdict said blocked, and no artifact showed caret-preserving editing under concurrent feedback. |
| `6bb265d9cc947bb854921508c4e8ddc33462af65` | blocked | The concurrent-editor and modal-help defects were repaired and verified from readable screenshots 11–17, but no artifact at that revision covered narrow/idle resize or the ASCII/no-colour fallback, and the cleanup captures were historical. |
| `81738e8a9e7278f872ab4b6c7c404c111607a4e2` | **accepted** | Ticket 32 replaced every checkpoint at `b94efda3…`: ASCII/no-colour (18, 19, 21), narrow/idle resize with help and dismissal (22–26), repeated prompts (27), a genuine required-value rejection and recovery (28, 29), cancel/interrupt cleanup (30, 31), plus re-captured concurrent editing, help and private entry (11–17). The fresh six-job matrix passed on a tree whose code is byte-identical. |
| `324e3d729cab0e19bff9e83ab34abee23ddc2394` (post-review) | **accepted, re-affirmed** | The native transports now ship a resize observer, so idle reflow is reachable instead of pending. The full suite (961), formatting (154 files), analysis, documentation links, the Windows console resize scenario, the POSIX PTY resize scenario and a fresh six-job matrix were re-run at this revision; the verdict, its artifact pointers and its limitations are unchanged. |

No earlier verdict is erased. Each one records what was actually observed at its
own revision, and no audit treats a resolved tracker state, a planned check or a
configured workflow as a pass.

## Accepted source revision and audit environment

- **Accepted source revision:**
  `81738e8a9e7278f872ab4b6c7c404c111607a4e2`
  (`merge(backend-gate): integrate final ticket 32 GUI evidence`, the local
  integration tip `d9d8790` merged into `ticket/backend-33-evidence-gate`).
- **One code revision, three hashes.** The accepted revision's code tree is
  byte-identical to `b94efda3779fe24ae41164ddd53015be7621d814`, the revision
  every GUI capture and every probe run in ticket 32 was made at: `git diff
  --stat b94efda 81738e8` lists only `assets/` and `docs/issues/` files, with no
  `lib/`, `test/` or `tool/` path differing. The matrix run cited below was
  triggered by a documentation-only commit on top of `81738e8`; its diff is the
  same audit file. Behaviour, captures and CI therefore describe one backend.
- **Audit environment:** Windows 11 Home `10.0.26200`, PowerShell
  `5.1.26100.9818`, Dart `3.13.2 (stable)`, `windows_x64`.
- **Computer-use provider:** orca `1.4.259`,
  provider `orca-computer-use-windows` `1.0.0`, protocol 1. `orca computer
  capabilities` reports screenshots and element frames, the action list
  `click, typeText, pressKey, hotkey, pasteText, scroll, drag, setValue,
  performAction`, no resize/move action, and `background=false`. It refused key
  input with `window_not_focused`; ticket 32 therefore used the repository's own
  Win32 `AttachConsole`/`WriteConsoleInput` injection for synthetic keys and an
  explicit Win32 `MoveWindow` for the resize checkpoint, both recorded in
  [gui/environment.txt](gui/environment.txt).
- **Input and profiles for local checks:** deterministic `ScriptedInput` and
  `StringBuffer` public seams, the declared ASCII (`40x8`, `ColorDepth.none`,
  `GlyphSet.ascii`) and rich visible profiles, and the real Windows-console and
  ConPTY wrappers. No real secret was used; the canary is synthetic.
- **Backlog state inspected:** the active tracker records tickets 01–32 as
  resolved; ticket 33 is resolved by this verdict; the finer 33-ticket plan in
  `dependencies.md` is the executed plan and the superseded layered decomposition
  is not claimed as implemented anywhere.

## Fresh platform and native evidence (B-PLATFORM)

Pushing the branch ran the whole workflow matrix:
[run 43741678302](https://github.com/louiss0/trelis/actions/runs/43741678302)
for source `a2900fbdb0d3e53abf7d8f0a93d23525e1df5341`, the commit that publishes
this verdict (documentation-only on top of `81738e8`), six jobs, every job
`success`. The workflow pins Dart 3.13.2. The same matrix had already passed one
commit earlier at `4eca00f`
([run 43740821935](https://github.com/louiss0/trelis/actions/runs/43740821935)),
the link repair; both runs cover the identical code tree, and the later run also
covers this audit's own links.

| Job | Runner/SDK | Executed result | Artifact |
| --- | --- | --- | --- |
| Dart | `windows-latest` (`windows-2025-vs2026`), `windows_x64`, Dart 3.13.2 | `Formatted 152 files (0 changed)`; `No issues found!`; `Checked 244 relative links in 58 Markdown files.`; `+952: All tests passed!` | [job 132895994628](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994628) |
| Dart | `ubuntu-latest` (`ubuntu-26.04`), `linux_x64`, Dart 3.13.2 | the same format, analysis and 244-link results; `+952: All tests passed!` | [job 132895994687](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994687) |
| Dart | `macos-latest` (`macos-26-arm64`), `macos_arm64`, Dart 3.13.2 | the same format, analysis and 244-link results; `+952: All tests passed!` | [job 132895994668](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994668) |
| POSIX native | Ubuntu, Dart 3.13.2 | ten public PTY scenarios `PASS`: `rich (alpha)`, `escape (cancel)`, `interrupt (interrupt)`, `signal (interrupt)`, `eof (eof)`, `error (alpha)`, `repeat (alpha,alpha)`, `session-retire (retired)`, `dumb-auto (alpha)`, `dumb-rich (unavailable:Rich interaction unavailable on the selected output; use linear or automatic mode.)` | [job 132895994435](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994435) |
| POSIX native | macOS arm64, Dart 3.13.2 | the same ten PTY scenarios `PASS` | [job 132895994673](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994673) |
| Windows native | `windows-latest`, Dart 3.13.2 | 17 `text input <scenario> PASS` lifecycle reports and six multiline pseudoconsole cases `PASS` | [job 132895994647](https://github.com/louiss0/trelis/actions/runs/43741678302/job/132895994647) |

The Windows native job reported the 17 scenarios this audit relies on: `rich`
(`alpha`), `linear-cursor` (`alphXa`), `linear-long`, `help-text-linear`,
`help-text-rich`, `help-password-linear`, `help-password-rich`,
`help-password-interrupt-linear`, `help-text-eof-rich`, `redirected`,
`dumb-auto`, `escape`, `interrupt`, `eof`, `error`, `repeat` (`alpha,alpha`),
`session-retire` (`retired`), each printing the console state before, during and
after the run; plus the pseudoconsole cases `framed-command`, `typed-command`,
`framed-multiline`, `editing`, `function-key`, `application-navigation`. This
satisfies the CI-only Linux/macOS requirement without adding a physical
Linux/macOS, human or local GUI checkpoint, and it exercises the new
capability/session/resize/measurement paths rather than a legacy script alone.

The same native wrappers were also re-run locally at the candidate, unchanged
and unwaived:

| Command | Actual printed result |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario rich -Report …` | `text input rich PASS result=alpha state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` |
| … `-Scenario linear-cursor` | `text input linear-cursor PASS result=alphXa state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` |
| … `-Scenario repeat` | `text input repeat PASS result=alpha,alpha state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` |
| … `-Scenario session-retire` | `text input session-retire PASS result=retired state=503:7:25:1 -> 496:7:25:1 -> 503:7:25:1` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1` | `framed-command`, `typed-command`, `framed-multiline`, `editing`, `function-key`, `application-navigation` all `PASS` |

Four of the seventeen console scenarios were re-run locally as a spot check of
the wrapper itself; the full seventeen and the six pseudoconsole cases are the
fresh CI results above, not a local claim.

## Local re-verification at the accepted revision

| Command | Actual result |
| --- | --- |
| `dart pub get` | `Got dependencies!`; `termunicode 0.2.0` resolved with `0.3.0` reported incompatible and not taken. |
| `dart format --output=none --set-exit-if-changed .` | Passed: `Formatted 152 files (0 changed) in 3.39 seconds.` |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 244 relative links in 58 Markdown files.` |
| `dart test --reporter compact` | Passed: `+952: All tests passed!` |
| `dart test test/gui_evidence_probe_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_feedback_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/output_profile_text_input_test.dart test/text_measurement_test.dart test/password_test.dart test/idle_text_input_resize_test.dart --reporter compact` | Passed: `+73: All tests passed!` |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | Passed: `+144: All tests passed!` |

The focused set exercises the public GUI-probe, help, modal-help, feedback,
short-screen/overflow, failure-recovery, capability/profile, measurement, secret
and resize seams. The full suite, the component matrix and the platform matrix
are stronger automated checks; none of them substitutes for the visible GUI
observation recorded below.

## Post-review re-verification at the resize revision

The native terminal I/O path changed, so every affected check was re-run at the
post-review revision `324e3d7`; the tables above stay as the record of the
previous accepted revision.

| Command | Actual result |
| --- | --- |
| `dart test test/gui_evidence_probe_test.dart test/native_resize_test.dart test/idle_text_input_resize_test.dart --reporter expanded` | `+16: All tests passed!` |
| `dart test --reporter compact` | `+961: All tests passed!` |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 154 files (0 changed)` |
| `dart analyze` | `No issues found!` |
| `dart run tool/check_doc_links.dart` | `Checked 232 relative links in 59 Markdown files.` after the evidence edits; the matrix job at the code revision printed `Checked 244 relative links in 58 Markdown files.` before them |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario resize -Report …` | `text input resize PASS result=0123456789…456789 state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` |
| `.github/workflows/platform-regression.yml` | six-job run `43747443317` at `324e3d7`: three Dart jobs (961 tests, 154 files formatted, analysis clean, links), two POSIX PTY jobs with eleven scenarios each, one Windows job with eighteen console scenarios and six pseudoconsole cases |

The added scenarios are the ones the resize fix makes possible: `resize` on the
Windows console shrinks the real buffer with no key injected and requires the
draft row to be rewrapped; the POSIX `resize` scenario does the same through a
real pseudo-terminal. Neither is a screenshot, and neither is counted as the
visible GUI observation.
## Ticket audit

| Ticket group | Tracker state | Audit result |
| --- | --- | --- |
| 01 baseline; 02 terminal I/O; 03 profiles; 04 native capability | resolved | Evidence records and current profile/native checks support them; the fresh matrix re-runs the native capability paths. |
| 05 safe rendering; 06 measurement; 07 narrow editor; 08 resize; 09 colour; 10 events; 11 help; 12 sessions | resolved | Current focused/full checks cover the public scripted seams; see their numbered reports in this directory. |
| 13 live status; 14 feedback lifecycles; 15 modal help; 16 short screen; 17 failure recovery | resolved | Current focused/full checks plus visible frames 11–15 and 25–26, 30–31 cover the feedback, help and cleanup behaviour. |
| 18 private entry through 30 compatibility/contract | resolved | Component matrix (144 tests at this revision), compatibility inventory, help, secret and migration evidence exist; current full suite passed. |
| 31 platform/native | resolved | **Pass at this revision**: the six-job matrix above, with the executed scenario lists. |
| 32 agent Windows GUI | resolved | **Pass at this revision**: every named B-GUI checkpoint captured at `b94efda3…` and inspected here; see the artifact audit below. |
| 33 final gate | resolved by this verdict | **Accepted**; this publication resolves the audit, not the backend implementation or the theme handoff. |

## Normative B requirement audit

| Requirement | Status | Evidence and limitation |
| --- | --- | --- |
| B-BASE | pass | `baseline.md`, `30-compatibility-and-contract.md`, the current full suite and the component matrix retain the source inventory and baseline; historical baseline failures are not counted as current passes. Historical limitations (the unexplained rich-input discrepancy, the outstanding broad NVDA baseline) are carried forward below. |
| B-CAP | pass | `ticket-03-output-profiles.md`, `ticket-04-native-capabilities.md`, `output_profile_text_input_test.dart` and the fresh native matrix: invocation/source/legacy/detection precedence, independent cursor/style/colour/glyph facts, stderr/stdout ownership, unknown/failed size queries, invalid declarations, dumb/redirected output and `NO_COLOR` absent/empty/non-empty are exercised. Synthetic rich fixtures declare positive geometry; no invented virtual 80x24 screen. |
| B-MEASURE | pass | `06-unicode-text-input-mapping.md`: `termunicode` pinned exactly to `0.2.0` in `pubspec.yaml`, lock archive SHA-256 `20ef0664…`, Unicode 16.0.0/MIT basis documented, only public scalar APIs used, frozen cluster/escape/tab policy, and ASCII/accented/decomposed/CJK/ambiguous/combining/format/flag/ZWJ/VS/keycap/control/bidi fixtures with grapheme-to-display and caret mappings. Not a universal terminal/font-width claim. |
| B-RENDER | pass | `05-safe-typed-text-input.md`, `09-text-input-colour-rendering.md`, `final-review-fixes.md`, the presentation-safety and colour suites, and the component matrix: immutable typed bodies, semantic slots, dedicated editable regions, wrapping, caret-centred scrolling, structural chrome accounting, omitted-protected-content safety insertion, opaque RGB/indexed/default colours with deterministic conversion, immutability and style restoration. Redirected real streams carry no ANSI; the synthetic recording fixtures are separate. |
| B-EVENT | pass | `ticket-10-linear-events.md`, the session/feedback/help suites and the full suite: current view versus ordered presentation events, no duplicated history on repaint/no-op/resize, fresh help/validation occurrences preserved despite identical text, region/source identity, one session-owned scripted reader across sequential prompts, and no submission inferred from snapshot diffs. |
| B-SESSION | pass | `ticket-12-scoped-session.md`, the session suites and the fresh native matrix: `TerminalSession.run` attachment, configuration inheritance, standalone temporary sessions, ownership-conflict errors, lazy acquisition, one prompt plus many feedback regions, second-prompt rejection before consumption, serialized writes, stable registration order with the prompt at the bottom, caret preservation while regions move, retired generations that cannot write, and honest alias limits. |
| B-FEEDBACK | pass | `13-prompt-live-status.md`, `14-multiple-feedback-lifecycles.md`, `17-session-failure-recovery.md`, the feedback/modal/short-screen suites and visible frames 11, 17, 30, 31: Progress/Spinner/MultiSpinner/Text semantics, cadence and outcomes; reaching the total is not success; disposal cancels no application job and invents no outcome; explicit outcomes commit once; coordinated `Text` writes do not corrupt the active editor. |
| B-PARITY | pass | `30-compatibility-and-contract.md`, the public compatibility inventory, `component_acceptance_matrix_test.dart` (`+144` at this revision) and the 952-test suite cover all 34 interactive and 4 feedback components, generics, decimal-string sliders, nullable number/colour answers, records, distinct cancelled/interrupted/input-ended/unavailable paths, async generation gates, source-stable SearchSelect references, response-local Autocomplete candidates, segmented drafts and reserved key capture. |
| B-HELP | pass | `11-text-input-help.md`, `30-compatibility-and-contract.md`, the help/modal suites and visible frames 14, 15, 19, 25, 26: component-help across families and stages, missing rich help paths without stealing capture gestures, primary actions and help access, format cues/warnings/validation under every instruction policy, current-stage-first full help, supplementary help as display lines, and draft/focus/caret maintained through help and fallback. |
| B-SECRET | pass | `18-private-entry-migration.md`, `password_test.dart`, and visible frames [16](gui/16-secret-actions.png)/[17](gui/17-final-accepted.png): synthetic canaries only; unmasked `Password` and hidden drafts leak no raw text, length or caret into projections, frames, history or diagnostics; optional masking and prefill warnings stay explicit; generic secret-validator failure behaviour preserved; per-component output policies asserted rather than a blanket redaction claim. The run ends `GUI-PROBE:accepted:alpXha;secret:accepted` and the canary never appears in any frame. |
| B-RESIZE | pass | `08-idle-text-input-resize.md` (`test/idle_text_input_resize_test.dart`: idle shrink repaint with caret clipping while retaining `abcdefgh` and caret 8, one opening event only, no fabricated geometry for identical/null/zero/throwing observations, watcher cancellation at prompt exit), `16-short-screen-overflow.md` (active prompt row reserved before ornament, `Feedback (n)` compaction in registration order, full notices retained with severity), `17-session-failure-recovery.md` (a failed resize repaint ends the prompt with the original failure), the native console observation (`lib/src/native_resize.dart`, `test/native_resize_test.dart`: POSIX `SIGWINCH`, a bounded Windows poll, unusable readings rejected, and a poll-only idle reflow at the public seam), the Windows `resize` console scenario (a real buffer shrink with no key sent rewraps the draft inside the new width) and the POSIX PTY `resize` scenario, plus visible frames [23](gui/23-resize-narrow-idle.png)/[24](gui/24-resize-narrow-repaint.png) for repaint/caret placement. Those frames predate the observer wiring and are not the reflow evidence; see the next section. |
| B-MODAL | pass | `15-modal-help-live-jobs.md`, the modal-help suite and visible frames 14, 15, 19, 25, 26: session-wide help owns painting in the transcript fallback while background jobs keep updating, dismissal restores the latest composite and a valid prompt state rather than a stale frame, notices survive the modal interval, `Ctrl+T` is not stolen from capture/literal-secret entry, and interruption/EOF/error exits behave. |
| B-FAIL | pass | `17-session-failure-recovery.md`, the failure suite and the native `session-retire` check: registration, local rendering, shared write, acquisition/restoration and callback failures are injected; local faults are isolated; a failed shared writer closes safely; registrations are drained, watchers stopped, leases released and received terminal state restored (`503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`, `496` for the 496 state); original failure context survives cleanup failure; late updates cannot write after closure. Forcible process termination and unmanaged external mutation are outside the contract. |
| B-COMPAT | pass | `30-compatibility-and-contract.md`, the public inventory and the full suite: public additions checked against the source inventory including part files, direct constructors still supported, invocation modes and results unchanged apart from the documented migrations (session/profile options, explicit synthetic geometry, plain/terminal-native default presentation, deliberate instruction-copy/layout changes), truthful README/CHANGELOG/examples, no package rename, and transcript changes reviewed semantically. |
| B-PLATFORM | pass | Fresh six-job matrix [43741678302](https://github.com/louiss0/trelis/actions/runs/43741678302) at the publishing revision `a2900fb` (code byte-identical to `81738e8`/`b94efda3`), detailed above, with runners, SDK, executed scenarios and job URLs. Linux/macOS remain CI-only and need no physical or human check. |
| B-GUI | pass | Every named checkpoint captured at one code revision and inspected below: keyboard editing, caret movement, concurrent feedback, help/dismissal, narrow/idle resize, ASCII/no-colour, secret-entry non-disclosure, cleanup and repeated sessions. NVDA absence recorded; agent input is automation, not human usability evidence. |
| B-GATE | **accepted** | This audit: every requirement above, every task 01–32 resolved, evidence re-run or re-captured after the changes, limitations and historical failures carried forward, no partial/planned/configured result counted as a pass, and only this explicit pass unblocks the separate theme handoff. It grants no release-wide accessibility claim. |

## Why the resize checkpoint now includes live reflow

B-RESIZE asks to "exercise idle resize, coalescing, safe unknown/zero geometry and
teardown of notifications/polling", to shrink padding/chrome and compact
background feedback before the active prompt, to preserve state during deferred
painting without duplicate events or lost input, and to "test actual
repaint/caret placement rather than only size arithmetic". The first audit
exercised every clause except one: the public `TerminalResizeObserver` seam had a
complete consumer but no shipped transport, so an idle native resize could only
be noticed by a keystroke. The seam is now reachable:
`lib/src/native_resize.dart` observes the console a prompt paints to, POSIX
forwards `SIGWINCH`, Windows keeps a bounded poll, and both native transports
supply it. Idle resize therefore repaints and reflows without a key in the
Windows console scenario and the POSIX PTY scenario recorded in
[post-review-fixes.md](post-review-fixes.md); the unknown/zero/throwing, cadence
and teardown clauses keep the coverage `08-idle-text-input-resize.md` records.

What is *not* claimed is a new visible-GUI capture of that reflow. Frames
[22](gui/22-resize-before.png)–[26](gui/26-narrow-help-dismissed.png) were taken
at `b94efda3…`, before the wiring existed, and they honestly show preservation
plus terminal soft wrap at the declared launch width. They stay as evidence of
that revision; they are not re-described as adaptive relayout, and no frame was
retouched. B-GUI's wording asks the agent to *cover* narrow/idle resize in a
visible terminal with expected-versus-observed notes, which those frames do,
while the live-reflow claim rests on the native and CI checks at this revision.

## B-GUI artifact audit

The canonical description of every frame — what each one shows, the synthetic
action that produced it, and the expected-versus-observed note — is the
[Screenshot inventory in the ticket-32 report](32-agent-windows-gui.md#screenshot-inventory).
This audit does not restate it. What was independently checked here is the
mapping from each named B-GUI checkpoint to the frames that satisfy it:

| B-GUI checkpoint | Frames checked at `b94efda3…` | Audit note |
| --- | --- | --- |
| Keyboard editing and caret movement | 11–13, 17 | The still frames prove the draft is unchanged after `Left`,`Left`; the later `X` insertion (`> alpXha`) is what makes the caret position checkable, and the same value is accepted. |
| Concurrent feedback while editing | 11–17 | `[status]` writes continue between every repaint and reach `#80` before the accepted outcome; no total-write count is claimed beyond the frames. |
| Help and dismissal | 14, 15, 19, 21, 25, 26 | Help owns its rows with real paragraph breaks, no literal `\u{000A}`, and the draft row cleared; dismissal repaints once. |
| ASCII/no-colour fallback | 18, 19, 21 | Plain default-on-default cells, ASCII glyphs, wrapped at exactly 40 columns, ending `GUI-PROBE:accepted:alpha`. |
| Narrow/idle resize | 22–26 | The window really is 620x420 in the image metadata; the draft and caret survive and the terminal soft-wraps, but this revision has no native observer, so no idle reflow is claimed from these frames. |
| Secret-entry non-disclosure | 16, 17 | 16 is the hidden-entry prompt, not the action chooser; the synthetic canary appears in no frame and only `GUI-PROBE:accepted:alpXha;secret:accepted` is printed. |
| Cleanup and repeated sessions | 27–31 | Two sequential prompts keep their own draft rows; a required empty submit is rejected once and recovers with `beta`; `Escape`/`Ctrl+C` retire both regions. |

All twenty frames are from `b94efda3…`; none is carried forward from an older
harness, and the five superseded `7676a5f` captures (`06`–`10`, including the
misleading "error-recovery" frame that only showed an optional empty submission)
are deleted rather than described as current rendering. Number `20` is
intentionally unused: the dismissal and outcome are both visible in `21`.

The same interleaving is driven deterministically by
`runGuiEvidenceProbe(pulses: …)`, `repeats`, `requireValue` and
`pulseInterval: Duration.zero` in `test/gui_evidence_probe_test.dart`, which
asserts the caret-relative transcript order, pulse counts, help line breaks,
absence of `\u{000A}`, one rejection then acceptance, and the absence of the
synthetic canary. That is automation and is **not** counted as the GUI
observation.
## Follow-ups required by the previous audit, and how each was closed

1. *Visible `--ascii` run with its own expected-versus-observed note.* Closed by
   18/19/21 and checkpoint two of the report.
2. *Narrow-window prompt and modal-help checkpoint despite a provider with no
   resize action.* Closed by 22–26 using an explicit Win32 `MoveWindow` on the
   provider-reported window handle, with the sizes verifiable from the images
   and the tooling limitation stated.
3. *Re-capture the repeated/error/cancel/interruption cleanups or state plainly
   that they are historical.* Closed by 27–31, captured at this revision; the
   historical captures were deleted.
4. *Correct the `16` description and the `06`–`10` inventory entries.* Closed in
   the report's inventory and its "Removed and superseded artifacts" section.

## Limitations carried forward

- **Linux/macOS** evidence is CI runner and PTY evidence only, as the contract
  requires. It is not physical-machine or GUI verification, and it does not need
  to be.
- **Windows native** checks inject console records or use a pseudoconsole. They
  do not prove physical keyboard, clipboard, IME, font rendering, screen-reader
  or human-usability behaviour.
- **Visible GUI** evidence is a single host, a single terminal family
  (Windows Terminal), and agent-generated synthetic input injected through Win32
  console records because the provider refused background key input and its
  `--restore-window` remedy would have taken over the human's screen and
  keyboard. The screenshots, not an accessibility tree, are the evidence.
  Nothing here qualifies physical-keyboard, IME, clipboard, compositor, font or
  pointer behaviour.
- **Resize** evidence now covers the scripted observer seam *and* a reachable
  native observation path: a real Windows console buffer shrink and a real POSIX
  PTY resize each reflow an idle prompt with no key sent. The visible GUI frames
  in `gui/` were captured before that wiring and are not re-taken here, so the
  adaptive-relayout claim rests on the native and CI checks, not on those stills.
- **NVDA** was absent (`nvda-command=; nvda-process-count=0`). There is no
  speech evidence, no screen-reader claim and no accessibility qualification of
  any kind; the historical broad-NVDA baseline remains outstanding.
- **Unicode measurement** states a supported cluster/width policy. Terminal and
  font behaviour beyond that policy is not universally asserted, and the
  historical unexplained rich-input discrepancy remains recorded as a
  limitation rather than a fresh pass.
- **Process termination and external mutation** after forcible kill or unmanaged
  terminal changes are outside the restoration contract.
- **Point-in-time statements.** Per-ticket reports such as
  [24](24-formatted-values-migration.md), [30](30-compatibility-and-contract.md)
  and [31](31-platform-evidence.md) say at their own revision that the backend
  evidence gate or B-GUI evidence was still pending. Those sentences describe
  the gate state at the time of writing and are superseded by this verdict; they
  are not rewritten, and no superseded layered task is presented as
  implemented.
- **Scope.** This verdict opens only the separate theme integration handoff. It
  is not a release-wide accessibility claim, an implementation result, or a
  substitute for the handoff's own verification matrix.

## Mirrored legacy gate

The accepted verdict and artifact pointers are mirrored into the retained
compatibility gate
[`issues/16-backend-evidence-gate.md`](../../../docs/issues/trelis-backend-implementation/issues/16-backend-evidence-gate.md),
with the statement that the finer 33-ticket plan was the executed plan and that
the superseded layered decomposition's tasks are not claimed as implemented.
That file, [ticket 31](../../../docs/issues/trelis-backend-tracer-bullets/issues/31-platform-ci-native-evidence.md),
[ticket 33](../../../docs/issues/trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md)
and the normative
[B requirements](../../../docs/issues/trelis-backend-implementation/spec.md) are
tracked by this branch, so the verdict no longer depends on untracked files on a
primary worktree.
