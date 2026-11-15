# Ticket 32 — agent-operated Windows GUI evidence

**Status:** pass for the concurrent-feedback and modal-help checkpoints; B-GUI
cleared.

## Verdict

At revision `a598c8e7a1415ce3f2411c8939cf4c589a44fab4` an agent drove the
public backend in a dedicated visible Windows Terminal window while a
`TerminalSession` prompt was live. The two defects that blocked B-GUI at
`7676a5f` are gone:

- concurrent `Spinner`/`Progress`/`Text` writes no longer corrupt the draft:
  the caret moved, an edit landed at that caret, and the accepted answer is
  `alpXha` (screenshot 13, final outcome screenshot 17);
- modal help is no longer malformed: paragraph breaks render as real lines
  instead of the literal spelling `\u{000A}`, and help replaces the draft row
  instead of being concatenated onto it (screenshots 14 and 15).

No accessibility qualification is claimed. See *Limitations*.

## Source and environment

- **Revision:** `a598c8e7a1415ce3f2411c8939cf4c589a44fab4` on branch
  `ticket/backend-32-windows-gui`; the probe harness is
  `tool/gui_evidence_probe.dart` at that revision.
- **Host:** Windows 11 Home `10.0.26200`.
- **Runtime:** Dart SDK `3.13.2 (stable)`, `windows_x64`.
- **Terminal:** Windows Terminal, dedicated window `prompty-ticket32-probe`
  (window id `2164156`, 1129x635), launched for this run by:
  `wt.exe -w -1 nt --title prompty-ticket32-probe --suppressApplicationTitle cmd /k "cd /d C:\Users\bvlou\projects\prompty-backend-ticket-32 && dart run tool/gui_evidence_probe.dart"`.
- **Computer use:** Orca `1.4.259`, provider `orca-computer-use-windows`
  `1.0.0`, protocol 1. Capabilities used: `screenshot`, `typeText`,
  `pressKey`, `hotkey`, window targeting by id. The provider reports
  `moveResize: false` and `focus: false`.
- **Input generation:** synthetic `orca computer press-key`, `hotkey`, and
  `type-text` calls into that window. Every action reported
  `verification: unverified (synthetic_input)`; a terminal leaves its input
  field empty, so screenshots — not an accessibility tree — are the artifact.
- **NVDA:** `Get-Command nvda` returned no command and `Get-Process nvda`
  returned zero processes, recorded in `gui/environment.txt`. No speech
  source, screen-reader behaviour, physical-keyboard, or human-usability claim
  is made.

## Exercise

The probe opens one session and starts one warning `Text`, one `Progress`
(`total: 3`) and one `Spinner`, then prompts for `TextInput('Project',
initialValue: 'alpha')` with two `supplementaryHelp` entries. From then on a
350 ms timer emits an informational `Text`, a `Spinner` update, and a
`Progress` advance while the editor owns the caret. The same interleaving is
driven deterministically by `runGuiEvidenceProbe(pulses: <stream>)` in the
scripted harness test.

Exact synthetic action sequence, in order:

| # | Action | Observed |
| --- | --- | --- |
| 1 | wait for the live prompt | draft row `> alpha`, `[status]` writes streaming above it (11) |
| 2 | `press-key Left`, `press-key Left` | caret between `alp` and `ha` (12; a still frame does not show the caret) |
| 3 | `type-text X` | draft row `> alpXha` (13) |
| 4 | `hotkey CmdOrCtrl+T` | help block on its own rows; draft row cleared (14) |
| 5 | `press-key Escape` | `> alpXha` repainted once on a fresh row (15) |
| 6 | `press-key Return` | `Project` submitted, `Password` prompt opens |
| 7 | `press-key Return` | password action chooser (16) |
| 8 | `type-text edit`, `Return` | hidden entry reopened; nothing echoed |
| 9 | `type-text SYNTHETIC`, `Return`, `type-text submit`, `Return` | `GUI-PROBE:accepted:alpXha;secret:accepted` (17) |

Expected versus observed:

- **Expected** `Left`,`Left`,`X` on `alpha` inserts at the moved caret and
  leaves `alpXha`. **Observed** `> alpXha` in 13 and the accepted value
  `alpXha` in 17.
- **Expected** concurrent feedback keeps reporting during editing without
  destroying the draft. **Observed** `[status]` lines continue between every
  prompt repaint in 11–15 (297 informational and 297 spinner writes by the
  end), and the draft still reads `alpXha`.
- **Expected** help paragraphs are separate display lines. **Observed** in 14:
  `Help: … Validation: An empty value is allowed.` then
  `This is an agent-operated synthetic-input probe,` then
  `not a human usability or accessibility claim.` No `\u{000A}` appears.
- **Expected** help owns painting and dismissal restores current state.
  **Observed** the draft row is absent while help is open (14) and is
  repainted exactly once as `> alpXha` after `Escape` (15), with no stale copy
  and no concatenated help text.
- **Expected** a private entry is not echoed. **Observed** the canary never
  appears in the transcript; only the outcome metadata is printed (16, 17).

## Screenshot inventory

`doc/evidence/trelis-backend/gui/`

| File | Content |
| --- | --- |
| `11-live-feedback-draft.png` | live prompt `> alpha` under continuous concurrent writes |
| `12-caret-moved.png` | after `Left`,`Left`; the still frame does not show the caret |
| `13-caret-edit.png` | after `X`; draft row `> alpXha` |
| `14-modal-help.png` | modal help in the transcript fallback, correct line breaks, draft row cleared |
| `15-help-dismissed.png` | after `Escape`; `> alpXha` repainted once |
| `16-secret-actions.png` | password action chooser; no secret disclosed |
| `17-final-accepted.png` | `GUI-PROBE:accepted:alpXha;secret:accepted` |
| `06-rich-feedback-profile.png`, `07-repeat-cleanup.png`, `08-error-recovery.png`, `09-cancel-cleanup.png`, `10-interrupt-cleanup.png` | captured at revision `7676a5f` and **not** re-run at `a598c8e` |

## Replaced evidence

The screenshots `01-modal-help.png` … `05-ascii.png` and the earlier version of
this report were produced by the run at `df490c9`, whose report text was stored
mis-encoded beyond recovery. They documented a *blocked* verdict for the
rendering defect above and are superseded by this revision's artifacts; they
were removed so no screenshot in this directory contradicts the verdict.

## Validation performed

| Command | Result |
| --- | --- |
| `dart test test/gui_evidence_probe_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_feedback_test.dart test/text_measurement_test.dart --reporter expanded` | passed, 25 tests |
| `dart test --reporter compact` | passed, 949 tests |
| `dart format --output=none --set-exit-if-changed .` | passed, 0 files changed |
| `dart analyze` | passed, `No issues found!` |
| `dart run tool/check_doc_links.dart` | see the evidence-gate record for the repository-wide result |

## Limitations

- Single-host, single-terminal observation. The provider cannot resize
  programmatically (`moveResize: false`), so this run made no narrow/idle
  resize checkpoint; the window was created at 1129x635.
- The ASCII/no-colour profile and the repeated-session, validation-error,
  cancellation and interruption cleanups are anchored to the earlier
  observations and to scripted tests at this revision; they were not re-run in
  this visible window. That gap is stated rather than papered over.
- Synthetic input is unverified by the provider; the screenshots are the
  evidence, and no claim is made about how a screen reader or a human would
  perceive any of it.
