# Final review fixes — backend tracer bullets

**Status:** pass for the scripted public seam at this revision. Every final-review
finding has a disposition; deferred items are heuristic deferrals with their
reason recorded, not silent omissions.

## Source and environment

- **Reviewed revision:** `29a7286` (`integration/trelis-backend-tracer-bullets`),
  delta baseline `80f4752`.
- **Fix branch:** `ticket/backend-final-review-fixes`, worktree
  `../prompty-backend-final-review`, started from `29a7286` and fast-forwarded
  through `c816001` (`ticket/backend-31-platform-evidence`, the cross-platform
  CI repair) before any runtime work.
- **Date:** 2026-11-14.
- **Environment:** Windows 11 (`10.0.26200.0`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`.
- **Input/output:** synthetic scripted streams and `StringBuffer` sinks, plus
  the public `TerminalSession`/feedback seam. No physical terminal, GUI or NVDA
  observation was performed here.
- **Review inputs:** `../prompty-review/standards-review.md`,
  `../prompty-review/spec-review.md`, their pinned
  `backend-tracer-bullets.diff`, `commits.txt` and `files.txt`.

## Finding dispositions

### Spec axis

| # | Finding | Disposition |
| --- | --- | --- |
| S1 | HIGH — colour applied before wrapping, so styled opening/validation lines print literal `\u{001B}` escapes and charge them to the width | **Fixed** — `_writeWrappedColorText` (feature `fix(text-input)`, `06aad38`); public tests in `test/text_input_colour_rendering_test.dart` |
| S2 | MEDIUM — `_feedbackSnapshots` never pruned: retired lines replay after help, `[!]` marks every later status, one retained line per `Text.present(session:)` | **Fixed** — `5af2d4f`; tests in `test/terminal_session_modal_help_test.dart` and `test/terminal_session_short_screen_test.dart` |
| S3 | MEDIUM/PARTIAL — standalone feedback claim was a no-op token, so only session-then-standalone was rejected | **Fixed** — `5f5e4bb`; tests in `test/terminal_session_feedback_test.dart` |
| S4 | LOW — validation colour dropped at both `_renderTextInputValidation` call sites | **Fixed** — `06aad38`; `test/text_input_colour_rendering_test.dart` |
| S5 | Hypothesis — the shared compositor repairs omissions only for `TextInput`, query/choice migrations have no equivalent safety-area path | **Not applicable at this revision, evidenced**: `QueryResultsPresentation` carries `DisplayText` values, and every result/query row reaches the terminal through `_writeWrappedColorText`/`DisplayText`, so the safety property (nothing raw is emitted) already holds. No structural query/choice declaration exists to omit a slot from; ticket 05's acceptance is `TextInput`-scoped and tickets 21/23 introduce the projection, not a declaration. A compositor path for query results would have no consumer and is left to the structural theme work. |

### Standards axis

| # | Finding | Disposition |
| --- | --- | --- |
| T1 | Duplicated lifecycle block (~20 copies): session dispatch, `_active`, `_terminalActive`, source/output/terminal validation | **Deferred (justified)** — the copies differ in `_run` signature, `ScriptedInput` construction, `_restoreAfter` typing and the `_terminal` callback; a shared seam needs a designed holder for the two per-instance flags and would rewrite the public invocation path of 21 sites. That is a structural change to the invocation seam, not a defect repair, and does not belong in a review-fix slice. Behaviour is unchanged and covered by the existing suites; the finding stays open with this pointer. |
| T2 | Duplicated profile preamble (~19 copies) | **Fixed** — `_effectiveOutputProfile` (`b8606f4`); all 21 scripted profile resolutions now share one order |
| T3 | Two display-escaping implementations with different control sets | **Fixed** — one `displaySafe` policy (`f7dfae3`); `test/text_input_test.dart` asserts the spelling does not depend on declared geometry |
| T4 | Asymmetric `OutputProfile.copyWith` (colour depth only), hand-written full reconstruction | **Fixed** — `copyWith` accepts every declared fact and `_constrainToObservedGeometry` uses it (`3d8005a`); `test/output_profile_text_input_test.dart` |
| T5 | Doc contradicts code: `TerminalIo.environment` says values are "not yet" used for profile resolution | **Fixed** — the doc now states the `NO_COLOR` hard restriction and that no other fact is resolved from the map (`cb6ea66`) |
| T6 | No-op claim token / Middle Man | **Fixed** — same change as S3 |
| T7 | Wrap-and-colour loop duplicated 8× (reviewer's list; 11 sites in the tree) | **Fixed** — the same `_writeWrappedColorText` helper; `9b5e14d` |
| T8 | `TreeNode` builds throwaway `Choice` values for validation | **Fixed** — `_checkChoiceText` used directly by `Choice` and `TreeNode` (`496c83a`) |
| T9 | `validOrder` is O(n²)+ with `candidate.indexOf` in a nested loop and opaque names | **Deferred (justified)** — the predicate also enforces that no element crosses a locked anchor, which a naive set/`indexOf` cleanup would silently drop; the ordering contract would have to be restated and re-verified first, and no measured cost exists (lists are caller-bounded, not session-sized). Recorded as a readability/performance follow-up. |
| T10 | ~70 of 160 published commits ignore the mandatory `type(scope):` format | **Not applicable, by instruction and by evidence** — the rule was introduced after those commits; published history is not rewritten. Every commit on this branch conforms (see `git log`). |
| T11 | `CapabilitySupport`, `GlyphSet`, `AmbiguousWidth`, `OutputGeometry` have no `GLOSSARY.md` entry | **Deferred (blocked, escalated)** — the repository's root `GLOSSARY.md` has uncommitted user edits and the work order forbids editing it from this branch. The four terms and their definitions are proposed in the hand-off report so the owner can add them where the glossary is maintained. |
| T12 | Minor: `terminalSgr` emits ANSI-16 for `ColorDepth.none`; only `_colorText` guards | **Fixed** — `terminalSgr` names the default parameters for an absent/unknown depth and `terminalStyledText` owns the guarded complete sequence (`cb6ea66`); tests in `test/text_input_colour_rendering_test.dart` |
| T13 | Coverage statement (no runtime verification by the reviewer) | Not a finding; no action. |

## Fix 1 — a component style is not display content

**Symptom.** `_renderTextInputOpening` and `_renderTextInputValidation` coloured
the text first and wrapped it second. `_writeWrappedText` measures through
`TextDisplayMap`, whose policy escapes `ESC` (a `Cc` code point), so the style
became visible text and its spelling was charged to the line width.

**Reproduction** at `29a7286` (probe file, deleted after use):

```
\u{001B}[38;2;1;2;3;48;2;4;5;6mName (Req
uired).\u{001B}[0m
Left/Right move; Home/End go to boundari
es; Backspace/Delete erase; Enter submit
s. Ctrl+T opens help. Escape cancels; Ct
rl+C interrupts.
```

**Red.** `wrapped labels carry component style as controls, not visible
escapes` expected `'\x1b[38;2;1;2;3;48;2;4;5;6mName (Required).\x1b[0m'` and
`isNot(contains(r'\u{001B}'))`; it failed with the output above.
`rejected answers are styled with the palette error role` failed with an
unstyled `Rejected name.` line.

**Green.** `_wrapText` now returns display lines and
`_writeWrappedColorText` styles each emitted line. The opening label is
`\x1b[38;2;1;2;3;48;2;4;5;6mName (Required).\x1b[0m`, the rejected answer line
carries `\x1b[38;2;15;16;17;48;2;4;5;6mRejected name.\x1b[0m`, and no literal
escape spelling appears. Both `_renderTextInputValidation` call sites now pass
`colors:`, which is finding S4.

## Fix 2 — feedback state follows its region

**Symptom.** A retired region kept its last line for the whole session, so
(a) `_restoreLatestComposite` re-emitted history after every help dismissal,
(b) `_hasImportantFeedback` stayed true after one failure and marked every later
short-screen status with `[!]`, and (c) `Text.present(session:)` retained one
snapshot per message forever.

**Red.** `dismissing help does not replay feedback the transcript already holds`
(one success line, two complete help intervals) expected one occurrence and saw
three. `a retired failure does not mark later short-screen status` expected the
newest composed line to be `[status] Feedback (1): Upload` and saw it marked
`[!]`.

**Green.** Snapshots are dropped on retirement and cleared on close/failure.
Lines that arrive while help owns painting are retained per region and written
once, in first-deferral order, when help returns (important notices in full,
ordinary ones summarized by the compact line). The severity marker follows the
newest emitted feedback line, so it describes current feedback without erasing
the documented post-failure indicator: the existing
`short feedback keeps failures reviewable and visibly severe` expectation
`[status] [!] Feedback (0)` immediately after the failure still holds.

## Fix 3 — a standalone claim is a real claim

**Symptom.** `claimStandaloneFeedbackOutput` called the guard and returned
`Object()` without registering, and `releaseStandaloneFeedbackOutput` was empty.
A session could take a sink that standalone feedback was already writing
unscoped `[status]` lines into.

**Red.** `standalone feedback that is still running refuses a second screen
owner` expected `TerminalSession.run` to throw `StateError` and saw it succeed.

**Green.** The claim is a reference-counted `_StandaloneFeedbackClaim` stored on
the sink: independent feedback regions still share one sink (pinned by
`standalone feedback regions remain source-compatible on one sink`), release is
real, and a session is refused until the last region finishes. A one-shot
`Text.present(output:)` line is not a screen owner and stays source-compatible
while standalone feedback writes the same sink. Session-then-standalone
rejection is unchanged.

## Fix 4 — one escaping policy

**Symptom.** `DisplayText.from` escaped C0/C1/DEL and bidi controls, while
`TextDisplayEntry.display` escaped the wider termunicode non-printable set
(`Cc`, `Cf`, `Cs`, `Cn`, `Co`, `Zl`, `Zp`) with a joiner exception. The same
application text therefore reached the terminal raw on an unwrapped line and as
a visible safety spelling on a wrapped one.

**Red.** `display escaping does not depend on declared geometry` prompted once
with declared geometry and once without. The wrapped run contained
`\u{E000}`; the plain run printed the private-use code point raw. Expected
`\u{E000}` in both, with the accepted answer unchanged.

**Green.** `displaySafe` in `text_measurement.dart` is the single policy;
`TextDisplayEntry.display` and `DisplayText.from` both use it. Answers, drafts
and callbacks are unchanged; only the display spelling changed (and only where
the narrower set had leaked).

## Fix 5 — profile facts and colour helpers

- `OutputProfile.copyWith` replaces any declared fact and preserves the rest;
  `_constrainToObservedGeometry` no longer restates all seven fields.
- `_effectiveOutputProfile` owns the resolution order and the `NO_COLOR` hard
  restriction for all 21 scripted sites (multiline and tag input included, which
  previously skipped the restriction because they never style).
- `terminalSgr` returns the default parameters (`39`/`49`) when the depth cannot
  express colour instead of the nearest ANSI-16 code; the new
  `terminalStyledText` returns unstyled text for `none`, `automatic` and an
  all-default palette, so a caller cannot forget the guard.

## Executed verification

| Command | Result |
| --- | --- |
| `dart pub get` | Passed: dependencies resolved. |
| `dart format --output=none --set-exit-if-changed .` | Passed: `Formatted 150 files (0 changed)`. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 155 relative links in 55 Markdown files.` |
| `dart test test/text_input_colour_rendering_test.dart test/text_input_test.dart test/presentation_safety_test.dart test/text_measurement_test.dart test/output_profile_text_input_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_session_test.dart test/tree_order_migration_test.dart test/tree_select_test.dart test/select_radio_test.dart --reporter expanded` | Passed: 127 tests. |
| `dart test test/component_acceptance_matrix_test.dart --reporter expanded` | Passed: 144 tests. |
| `dart test --reporter expanded` | Passed: 937 tests. |
| `git diff --check` | Passed: no whitespace errors. |

Red/green pairs are named per fix above; each red assertion was observed failing
before the corresponding implementation and passing after it.

## Limitations

- Everything above is deterministic scripted behaviour on Windows. No native
  PTY, physical terminal, GUI, NVDA or Linux/macOS observation was made here;
  the final cross-platform CI rerun after these runtime fixes is still required
  and a branch revision is not a final-gate pass.
- One full-suite run early in the branch reported two failures whose names were
  truncated out of the captured output; the three subsequent complete runs
  passed every test (930, then 937 twice). The two failures are recorded as
  unexplained rather than as a pass.
- The lifecycle duplication (T1) and the ordering predicate (T9) remain as
  recorded follow-ups with their reasons; the glossary entries (T11) wait on the
  owner's uncommitted `GLOSSARY.md` edits.
- `ColorDepth.automatic` is still treated as "unknown, so no colour" at the
  colour helper. That matches the previous `_colorText` guard, but it means an
  unresolved profile never styles.
- The compact short-screen summary still drops ordinary (non-important)
  informational lines when no rows remain; only warnings, errors and explicit
  outcomes are written in full. That is the ticket-16 behaviour, now without the
  retained-snapshot replay.

## Follow-up corrections for ticket 31

Revision `cf33023` on `ticket/backend-31-platform-evidence` addresses the
follow-up review against integration `07da9ba`. It is local, focused evidence;
it does not amend the historical full-suite or CI results above.

- **Modal notices:** a deferred feedback occurrence now has a sequence identity.
  Important notices remain in arrival order even if a later ordinary update from
  the same `MultiSpinner` region replaces its live snapshot. The restoration
  filter compares sequence identity, not displayed text, so equal text from
  separate regions and repeated equal notices remain separate events.
- **ZWJ display spelling:** `displaySafe` applies its policy one grapheme at a
  time, exactly as `TextDisplayMap` does. A dangling joiner is now visible in
  both unwrapped and wrapped presentation; supported emoji ZWJ clusters stay
  intact.
- **Profile/API gaps:** `OutputProfile.isAutomatic` owns the all-facts predicate
  that `TextInput` previously duplicated. `copyWith` documentation states that
  its non-null automatic sentinels clear declared facts. `terminalStyledText`
  documents that it does not escape application text and requires display-safe
  input.
- **Native preference fixture:** the Windows test injector previously assigned
  `.` virtual key 46 (`VK_DELETE`), so the preference-change draft lost its
  grouping separator. It now emits OEM punctuation virtual keys, and the
  existing registry-restoring `finally` branch passed.

Red was observed before each implementation: the modal test found zero retained
`compile: failed: broken` lines, `DisplayText.from('a\u200Db')` retained a raw
joiner, and the profile test could not resolve `isAutomatic`. After the fixes,
this focused command passed with **94 tests** on Windows 11 (`10.0.26200.0`),
Dart `3.13.2`:

```text
dart test test/terminal_session_modal_help_test.dart \
  test/terminal_session_short_screen_test.dart test/text_input_test.dart \
  test/text_measurement_test.dart test/output_profile_text_input_test.dart \
  test/text_input_colour_rendering_test.dart test/number_input_test.dart \
  test/formatted_values_migration_test.dart --reporter expanded
```

`test/number_input_native_checks.ps1` also passed its rich, linear, and guarded
preference-change cases. `dart test --reporter expanded` passed with **946
tests**. A fresh six-job CI run is required before these local follow-up repairs
are counted as platform evidence.
