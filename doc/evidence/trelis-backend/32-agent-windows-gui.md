# Ticket 32 — agent-operated Windows GUI evidence

**Status:** pass for every named B-GUI checkpoint at one code revision. B-GUI is
cleared; B-GATE is not opened here because that verdict belongs to ticket 33.

## Verdict

At code revision `b94efda3779fe24ae41164ddd53015be7621d814` an agent drove the
public backend in dedicated visible Windows Terminal windows and inspected the
resulting frames. Every checkpoint ticket 33 named as missing or historical is
now captured at that revision:

- ASCII/no-colour fallback under `tool/gui_evidence_probe.dart --ascii`
  ([18](gui/18-ascii-prompt.png), [19](gui/19-ascii-help.png),
  [21](gui/21-ascii-outcome.png));
- narrow/idle resize with modal help and dismissal
  ([22](gui/22-resize-before.png) → [23](gui/23-resize-narrow-idle.png) →
  [24](gui/24-resize-narrow-repaint.png) → [25](gui/25-narrow-help.png) →
  [26](gui/26-narrow-help-dismissed.png));
- repeated prompts in one session ([27](gui/27-repeat-sessions.png));
- a genuine required-value rejection that recovers
  ([28](gui/28-validation-rejected.png), [29](gui/29-validation-recovered.png));
- cancellation ([30](gui/30-cancel-cleanup.png)) and interruption
  ([31](gui/31-interrupt-cleanup.png)).

The concurrent-feedback, modal-help and private-entry checkpoints
([11](gui/11-live-feedback-draft.png)–[17](gui/17-final-accepted.png)) were
re-captured at this same revision rather than carried forward, so no frame in
this directory predates the current harness.

No accessibility qualification is claimed. See *Limitations*.

## Source and environment

- **Candidate code revision:** `b94efda3779fe24ae41164ddd53015be7621d814`
  (`feat(gui-probe): let a visible run quieten its concurrent writes`), on
  branch `ticket/backend-32-windows-gui`, with the local integration tip
  `75719dd34b0a20604d4b2ee196c9f2dc67d49676` merged at
  `9963ce0efde78f8607293973b009dfd24e629d7c` (ancestry verified with
  `git merge-base --is-ancestor 75719dd HEAD`, exit status 0).
- **Harness changes at this revision:** `46e1a6ea3a5167ba267cb6f3e5b83f6deb173567`
  added `repeats`/`requireValue` to `runGuiEvidenceProbe`,
  `b94efda3…` added the zero-`pulseInterval` quiet path. Neither touches
  `lib/`; the library under test is byte-identical to
  `a598c8e7a1415ce3f2411c8939cf4c589a44fab4` for every file this evidence
  exercises.
- **Host:** Windows 11 Home `10.0.26200`, PowerShell `5.1.26100.9818`.
- **Runtime:** Dart SDK `3.13.2 (stable)`, `windows_x64`
  (`C:\Users\bvlou\AppData\Local\Microsoft\WinGet\Packages\Google.DartSDK_…\dart-sdk\bin\dart.exe`).
- **Terminal:** Windows Terminal, one dedicated window per scenario
  (`prompty-ascii`, `prompty-resize`, `prompty-repeat`, `prompty-validation`,
  `prompty-cancel`, `prompty-interrupt`, `prompty-rich`), created with
  `wt.exe -w -1 nt --title <name> --suppressApplicationTitle cmd /k "cd /d C:\Users\bvlou\projects\prompty-backend-ticket-32 && dart run tool/gui_evidence_probe.dart <flags>"`.
  Window ids observed by the provider: `1246864`, `2229810`, `2557954`,
  `1771318`, `2689026`, `5899718`, `2033328`; the default launch size was
  1129x635.
- **Computer use — observation only:** Orca `1.4.259`, provider
  `orca-computer-use-windows` `1.0.0`, protocol 1. `orca computer
  capabilities` reports `Observation: screenshot=true elementFrames=true`, the
  action list `click, typeText, pressKey, hotkey, pasteText, scroll, drag,
  setValue, performAction`, **no resize/move action**, and
  `Input: background=false`. Every screenshot was taken with
  `orca computer get-app-state --app WindowsTerminal --window-id <id> --json`,
  which returned the png path copied into this directory.
- **Synthetic input — Win32 console injection:** Orca refused key input:
  `orca computer press-key --app WindowsTerminal --window-id 2557210 --key
  Escape` returned `window_not_focused: keyboard input requires the target
  window to be focused … nothing was sent`. The provider's remedy
  (`--restore-window`) takes over the human's screen and keyboard and is
  documented as never to be added without asking the user, so it was **not**
  used. Keys were injected with the same Win32 pattern the repository's own
  native probes use (`test/text_input_windows.ps1`,
  `test/terminal_probe_windows.ps1`): a separate `powershell.exe` calls
  `FreeConsole()`, `AttachConsole(<dart pid>)`, opens `CONIN$` and writes
  `KEY_EVENT` records with `WriteConsoleInput`. Injection is therefore
  agent-generated synthetic input that bypasses the physical keyboard, and the
  screenshots — not an accessibility tree — are the evidence.
- **Resize method:** the provider has no `moveResize` action, so the window was
  resized with an explicit Win32 call,
  `MoveWindow(<window handle>, 122, 130, <width>, <height>, true)`, using the
  handle the provider reports for the window (`2229810`). It returned `True`
  for `1000x620` and `620x420`, and the screenshot metadata for
  [22](gui/22-resize-before.png)/[23](gui/23-resize-narrow-idle.png) reports
  exactly those sizes.
- **NVDA:** re-checked at capture time — `Get-Command nvda` returned nothing and
  `Get-Process nvda` returned zero processes, recorded in
  [gui/environment.txt](gui/environment.txt) as
  `nvda-command=; nvda-process-count=0`. No speech source exists, so no
  screen-reader behaviour is claimed.

## Scenario harness

`tool/gui_evidence_probe.dart` opens one `TerminalSession`, writes one warning
`Text`, one `Progress` (`total: 3`) and one `Spinner`, then prompts. Flags at
this revision:

| Flag | Effect |
| --- | --- |
| `--ascii` | fixed 40x8 no-colour ASCII profile (`ColorDepth.none`, `GlyphSet.ascii`, styles/alternate screen unsupported) |
| `--no-secret` | stop after the text prompts |
| `--repeats=N` | N sequential prompts inside one session |
| `--require-value` | draft opens empty and the value is required, so an immediate submit is rejected by the shared validation path |
| `--pulse-interval=MS` | concurrent `Text`/`Spinner`/`Progress` cadence; `0` keeps the regions live without periodic writes so a still frame stays readable |

The default run keeps the 350 ms pulse; the ASCII, resize, repeat, validation
and cleanup runs used `--pulse-interval=0` (stated per checkpoint below).

## Checkpoint one — concurrent editing, modal help, private entry (rich run)

Default flags, 350 ms pulses, window `prompty-rich` (`2033328`). Synthetic
actions in order, all by injection, with the frame that shows each:

| # | Synthetic action | Frame and observed result |
| --- | --- | --- |
| 1 | wait for the live prompt | [11](gui/11-live-feedback-draft.png): draft `> alpha`, `[status] Concurrent informational write #4…#17` streaming above it, `Indexing … 100% (3/3)` already reported |
| 2 | `VK_LEFT` ×2 | [12](gui/12-caret-moved.png): draft unchanged, writes continue (#15…#29). The caret block sits inside the draft; a still frame cannot prove an exact column, so the *edit* below is what makes the position checkable |
| 3 | char `X` | [13](gui/13-caret-edit.png): `> alpXha` with the caret after `X`, writes continuing (#24…#38) |
| 4 | `Ctrl+T` | [14](gui/14-modal-help.png): help owns its own rows, `Validation: An empty value is allowed.` ends the first paragraph, the two `supplementaryHelp` entries appear as separate display lines, no literal `\u{000A}`, and **the draft row is absent** while help is open |
| 5 | `VK_ESCAPE` | [15](gui/15-help-dismissed.png): `Help dismissed.` then `> alpXha` repainted once, no stale help text and no duplicated draft row, writes continuing (#41…#58) |
| 6 | `VK_RETURN` | [16](gui/16-secret-actions.png): `Synthetic canary (Optional). Hidden entry; Enter opens actions. Ctrl+T opens help; Escape cancels; Ctrl+C interrupts.` with the accepted draft still shown above; nothing echoed |
| 7 | `SYNTHETIC` + `VK_RETURN` | the hidden entry is entered; no frame of that state is kept (it showed no echo, which [16](gui/16-secret-actions.png) already establishes) |
| 8 | `submit` + `VK_RETURN` | [17](gui/17-final-accepted.png): `Actions: submit, edit, clear, help, cancel. /help and /cancel are also available. Enter an action:` is the action cue, then `[status] … completed` for both regions and `GUI-PROBE:accepted:alpXha;secret:accepted` |

Expected versus observed:

- **Expected** `Left`,`Left`,`X` insert at the moved caret. **Observed**
  `> alpXha` in [13](gui/13-caret-edit.png), the same value accepted in
  [17](gui/17-final-accepted.png).
- **Expected** concurrent feedback keeps reporting without destroying the
  draft. **Observed** writes continue between every repaint in 11–15 with the
  draft intact; the visible counters reach `#80` in
  [17](gui/17-final-accepted.png). No total-write count is claimed beyond what
  the frames show.
- **Expected** help paragraphs are separate display lines. **Observed** in
  [14](gui/14-modal-help.png): one paragraph ending
  `Validation: An empty value is allowed.`, then `This is an agent-operated
  synthetic-input probe,`, then `not a human usability or accessibility
  claim.`, with no `\u{000A}`.
- **Expected** help owns painting and dismissal restores current state.
  **Observed** draft row absent in [14](gui/14-modal-help.png), single repaint
  to `> alpXha` in [15](gui/15-help-dismissed.png).
- **Expected** a private entry is not echoed. **Observed** the canary never
  appears in any frame; only `GUI-PROBE:accepted:alpXha;secret:accepted` is
  printed.

## Checkpoint two — ASCII/no-colour fallback

`--ascii --no-secret --pulse-interval=0`, window `prompty-ascii` (`1246864`),
1129x635 with a declared 40-column geometry.

| # | Synthetic action | Frame and observed result |
| --- | --- | --- |
| 1 | wait for the prompt | [18](gui/18-ascii-prompt.png): every cell is plain default-on-default — no SGR colour, no bold, ASCII glyphs only — and the help line is wrapped by the backend at 40 columns (`Left/Right move; Home/End go to boundari` / `es; Backspace/Delete erase; Enter submit` / `s. Ctrl+T opens help. Escape cancels; Ct` / `rl+C interrupts.`); draft `> alpha` with a visible caret |
| 2 | `Ctrl+T` | [19](gui/19-ascii-help.png): help block on its own rows, still uncoloured and ASCII, still wrapped at 40 columns, `Validation: An empty value is allowed.` present, both supplementary lines present as separate display lines, no `\u{000A}`, **draft row absent** |
| 3 | `VK_ESCAPE` then `VK_RETURN` | [21](gui/21-ascii-outcome.png): `Help dismissed.`, `> alpha` repainted once, `[status] Indexing … 100% (3/3)`, `[status] … completed` for both regions, and `GUI-PROBE:accepted:alpha` |

Expected: the same behaviour as the rich profile with no colour and no
non-ASCII glyph, wrapping at the declared width. Observed: exactly that, and
the fallback ends with the plain-text outcome line.

## Checkpoint three — narrow/idle resize, modal help, dismissal

`--no-secret --pulse-interval=0` (visible terminal geometry, declared at
launch), window `prompty-resize` (`2229810`).

| # | Action | Frame and observed result |
| --- | --- | --- |
| 1 | `MoveWindow` → 1000x620 | [22](gui/22-resize-before.png): idle prompt, help line wrapped at the declared width, draft `> alpha` |
| 2 | `MoveWindow` → 620x420, no key | [23](gui/23-resize-narrow-idle.png): the window is narrow; the already-painted rows are soft-wrapped by the terminal (`while th` / `e editor is active.`), the draft is preserved and no repaint is triggered by the resize itself |
| 3 | `VK_LEFT` (forces a repaint) | [24](gui/24-resize-narrow-repaint.png): draft and logical caret retained (`> alph` with the caret block before the final `a`); the repaint still uses the declared launch width, so rows remain split by terminal soft wrap |
| 4 | `Ctrl+T` | [25](gui/25-narrow-help.png): help block owns its rows at narrow width, paragraph breaks intact, `Validation: An empty value is allowed.`, **draft row cleared** |
| 5 | `VK_ESCAPE` | [26](gui/26-narrow-help-dismissed.png): `Help dismissed.` and one repaint of `> alpha`, no stale help and no stale draft row |

Expected versus observed, stated precisely because this checkpoint is where
overclaiming is easiest:

- **Expected** a resize must not corrupt the draft, the caret or the
  presentation events. **Observed** the draft and caret survive both the idle
  resize and the forced repaint ([23](gui/23-resize-narrow-idle.png),
  [24](gui/24-resize-narrow-repaint.png)).
- **Expected, and not delivered:** an idle resize does **not** repaint by
  itself. The visible adapter declares a fixed geometry at launch
  (`OutputGeometry.fixed(columns: stderr.terminalColumns, …)`) and the built-in
  Windows adapter exposes no resize notification, which
  [08-idle-text-input-resize.md](08-idle-text-input-resize.md) already records
  as pending native observer wiring. The frame shows the honest consequence:
  the terminal soft-wraps already-painted rows, and the next repaint still uses
  the launch width. This is a captured limitation of the visible adapter, not a
  claim that live resize reflows text.
- **Expected** modal help and dismissal behave the same at narrow width.
  **Observed** yes ([25](gui/25-narrow-help.png),
  [26](gui/26-narrow-help-dismissed.png)).

## Checkpoint four — repeated prompts in one session

`--repeats=2 --no-secret --pulse-interval=0`, window `prompty-repeat`
(`2557954`).

| # | Action | Frame and observed result |
| --- | --- | --- |
| 1 | `VK_RETURN`, `VK_RETURN` | [27](gui/27-repeat-sessions.png): two sequential `Project (Optional).` blocks, each painting `> alpha` on its own rows, then `[status] Indexing … 100% (3/3)`, both regions `completed`, and `GUI-PROBE:accepted:alpha,alpha` |

Expected: a second prompt in the same session starts from a clean draft row,
keeps its own help, and returns its own value. Observed: exactly that, with no
leftover row from the first prompt and both values in the outcome.

## Checkpoint five — genuine validation error, then recovery

`--require-value --no-secret --pulse-interval=0`, window `prompty-validation`
(`1771318`). The draft opens empty and the value is required, so an immediate
submit is a real rejection rather than an accepted empty answer.

| # | Action | Frame and observed result |
| --- | --- | --- |
| 1 | `VK_RETURN` on the empty draft | [28](gui/28-validation-rejected.png): header `Project (Required).`, empty draft `>`, then `Required: enter a non-empty value and submit again.`, then a **new** empty prompt row `>` — exactly one rejection and the prompt is live again |
| 2 | `beta` + `VK_RETURN` | [29](gui/29-validation-recovered.png): the rejected rows stay in the transcript, `> beta` accepted, `[status] … completed` for both regions, `GUI-PROBE:accepted:beta` |

Expected: one rejection with a readable message and a usable prompt, then a
successful submission of a real value. Observed: exactly that, and the outcome
line proves the accepted value is `beta`, not the rejected empty string.

## Checkpoint six — cancellation and interruption cleanup

`--no-secret --pulse-interval=0`. Windows `prompty-cancel` (`2689026`) and
`prompty-interrupt` (`5899718`).

| # | Action | Frame and observed result |
| --- | --- | --- |
| 1 | `VK_ESCAPE` at the live prompt | [30](gui/30-cancel-cleanup.png): `[status] Indexing visible GUI evidence: completed`, `[status] Background activity: completed`, `GUI-PROBE:cancel` |
| 2 | `Ctrl+C` at the live prompt | [31](gui/31-interrupt-cleanup.png): the same two `completed` lines and `GUI-PROBE:interrupt` |

Expected: both named regions are retired with a completed outcome, the shell
prompt returns, and no stale region keeps writing. Observed: both
([30](gui/30-cancel-cleanup.png), [31](gui/31-interrupt-cleanup.png)). The last
painted `> alpha` row remains in the transcript, which is what a terminal does
with already-written cells; no post-cancel repaint appears after the outcome
line. Forcible process termination is outside this contract.

## Screenshot inventory

`doc/evidence/trelis-backend/gui/` — every file below was captured and
inspected at `b94efda3779fe24ae41164ddd53015be7621d814`.

| File | Content |
| --- | --- |
| `11-live-feedback-draft.png` | live draft `> alpha` under continuous concurrent writes |
| `12-caret-moved.png` | after `Left`,`Left`; draft unchanged, caret inside the draft (a still frame cannot prove the exact column) |
| `13-caret-edit.png` | after `X`; `> alpXha` under continuing writes — the position is checkable here |
| `14-modal-help.png` | modal help in the transcript fallback: own rows, paragraph breaks as lines, supplementary entries as separate lines, no `\u{000A}`, draft row cleared |
| `15-help-dismissed.png` | after `Escape`; `Help dismissed.` and one repaint of `> alpXha` |
| `16-secret-actions.png` | hidden-entry prompt `Synthetic canary (Optional). Hidden entry; Enter opens actions.` with nothing echoed (this is **not** the action chooser, correcting the earlier description) |
| `17-final-accepted.png` | action cue `Actions: submit, edit, clear, help, cancel. …`, completed regions, `GUI-PROBE:accepted:alpXha;secret:accepted` |
| `18-ascii-prompt.png` | `--ascii` live prompt: plain, uncoloured, ASCII, help wrapped at 40 columns, draft `> alpha` |
| `19-ascii-help.png` | `--ascii` modal help: own rows, 40-column wrap, both paragraphs, draft row cleared |
| `21-ascii-outcome.png` | `--ascii` after dismissal and submit: `Help dismissed.`, `> alpha`, completed regions, `GUI-PROBE:accepted:alpha` |
| `22-resize-before.png` | narrow checkpoint, before: idle prompt at 1000x620 |
| `23-resize-narrow-idle.png` | after `MoveWindow` to 620x420 with no key: draft preserved, rows soft-wrapped by the terminal, no repaint |
| `24-resize-narrow-repaint.png` | the repaint forced by `Left`: draft and caret retained, still at the declared launch width |
| `25-narrow-help.png` | modal help at narrow width: own rows, draft row cleared |
| `26-narrow-help-dismissed.png` | `Help dismissed.` and one repaint of `> alpha` at narrow width |
| `27-repeat-sessions.png` | two sequential prompts in one session, `GUI-PROBE:accepted:alpha,alpha` |
| `28-validation-rejected.png` | required-value rejection: `Required: enter a non-empty value and submit again.` and a fresh prompt |
| `29-validation-recovered.png` | recovery: `> beta` accepted, `GUI-PROBE:accepted:beta` |
| `30-cancel-cleanup.png` | `Escape`: both regions completed, `GUI-PROBE:cancel` |
| `31-interrupt-cleanup.png` | `Ctrl+C`: both regions completed, `GUI-PROBE:interrupt` |

## Removed and superseded artifacts

- `06-rich-feedback-profile.png` … `10-interrupt-cleanup.png` were captured at
  `7676a5f`, before `429526b` rewrote paragraph wrapping and added the
  draft-row clear. `06` still showed the superseded defect (help concatenated
  onto the draft with a literal `\u{000A}`) and `08` was named "error-recovery"
  but showed an optional empty submission, not a validation error. They are
  deleted rather than described, and their checkpoints are replaced by
  [27](gui/27-repeat-sessions.png)–[31](gui/31-interrupt-cleanup.png) captured
  at the current revision.
- `20-ascii-help-dismissed.png` and a hidden-entry frame were captured in this
  run and not kept: `21` already shows the dismissal *and* the outcome, and the
  hidden-entry frame added no fact that [16](gui/16-secret-actions.png) does not
  already show. Number `20` is intentionally unused.
- The earlier `01-modal-help.png` … `05-ascii.png` set from `df490c9` was
  already removed at `a598c8e`; nothing here reinstates it.

## Validation performed

| Command | Actual result |
| --- | --- |
| `dart test test/gui_evidence_probe_test.dart --reporter expanded` | passed, 4 tests, including one rejection then acceptance and a quiet-run assertion |
| `dart test test/gui_evidence_probe_test.dart test/text_input_help_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_feedback_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/output_profile_text_input_test.dart test/text_measurement_test.dart test/password_test.dart test/idle_text_input_resize_test.dart --reporter compact` | passed, `+73: All tests passed!` |
| `dart test --reporter compact` | passed, `+952: All tests passed!` |
| `dart format --output=none --set-exit-if-changed .` | passed, `Formatted 152 files (0 changed)` |
| `dart analyze` | passed, `No issues found!` |
| `dart run tool/check_doc_links.dart` | passed, `Checked 213 relative links in 57 Markdown files.` |

The scripted suites drive the same seams deterministically
(`runGuiEvidenceProbe(pulses: …)`, `repeats`, `requireValue`,
`pulseInterval: Duration.zero`). They are automation and are **not** counted as
the GUI observation above.

## Limitations

- Single host, single terminal family, agent-generated synthetic input. The
  input path is Win32 console injection, not the physical keyboard and not the
  provider's own input channel; Orca supplied observation and screenshots only.
  Nothing here qualifies physical-keyboard, IME, clipboard, compositor, font or
  pointer behaviour.
- The provider cannot resize and was not given foreground input, so the resize
  checkpoint used an explicit Win32 `MoveWindow` on the window the provider
  reported, and every frame was taken in the background. A foreground run could
  differ (focus, cursor shape) without contradicting anything recorded here.
- The visible adapter declares a fixed geometry at launch and has no native
  resize notification, so live resize does not reflow the prompt. What the
  narrow frames show is preservation plus terminal soft wrap, not adaptive
  relayout.
- NVDA was absent, so there is no speech evidence and no accessibility
  qualification of any kind.
- Text is captured as a png of a rendered terminal; the transcript of record for
  behaviour remains the public scripted tests, and the frames are the visible
  cross-check.
