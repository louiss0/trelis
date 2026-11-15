# Backend post-review fixes — ticket 33 follow-up

**Verdict: the accepted backend gate is re-affirmed at this revision.**

This record answers the final two-axis review of the backend tracer bullets. It
is not a new gate decision made in isolation: it re-runs the checks the
[acceptance audit](backend-acceptance.md) relies on after a production change to
the native terminal I/O path, and it records a disposition for every review
finding so a later reader can tell a fix from a false positive.

Base: local integration `403fad5` (`merge(backend): integrate ticket 33 accepted
backend gate`). Nothing here is merged into integration; the branch
`ticket/backend-post-review-fixes` stops at the commits below.

## Standards findings

### 1. Ticket 33 used `## Claim`/`## Result` instead of `## Comments`

**Fixed.** The tracker convention keeps conversation and history under
`## Comments` (`docs/agents/issue-tracker.md`). Ticket 33 now records its claim
and its accepted verdict as labelled paragraphs inside one `## Comments`
section. No verdict text was dropped: the third-audit statement, the accepted
artifact list and the limitations were moved, not rewritten.

### 2. Historical commit `8b21f53` has a nonconforming merge subject

**Disposition: retained, not rewritten.** `8b21f53` is
`Merge branch 'integration/trelis-backend-tracer-bullets' into
ticket/backend-32-windows-gui`, which does not follow
`<type>(<scope>): <subject>`.

It is shared history, not local work: it is reachable from
`integration/trelis-backend-tracer-bullets`, from `origin` (the ticket 33 branch
was pushed), and therefore from every run URL and artifact pointer the accepted
audit cites. Rewriting it would change the hashes of the six-job matrix run, the
GUI captures' revision and the audit's own "one code revision" argument — the
exact evidence this gate rests on — to fix a message on a merge that changes no
tree content. The cost of the exception is recorded here; the alternative is
trading durable evidence for cosmetics on shared, already-published history.

Every commit authored by this branch follows the convention.

### 3. `_isAutomaticProfile` was a middle-man wrapper

**Fixed** in `refactor(text-input): read the automatic profile fact directly`.
The session guard compares `outputProfile.isAutomatic` directly, and the
one-line wrapper is gone.

### 4. `GuiEvidenceProbe.pulses` was a speculative getter

**Fixed** in `refactor(gui-probe): give the repeat contract one owner`. Nothing
read the counter; the private field that produces the write text stays.

### 5. Duplicated GUI-probe test setup

**Fixed** in `test(gui-probe): share one scripted probe harness`. One
`_ProbeHarness` owns the input/pulse controllers, the profile, `settle`, `type`,
`pulse` and `finish`; the four existing scenarios kept their assertions, and the
new repeat-contract test uses the same harness.

### 6. Duplicate positivity validation for `--repeats`

**Fixed** in `refactor(gui-probe): give the repeat contract one owner`. The flag
parser now rejects only a malformed or negative value, so `--repeats=0` reaches
the probe's single positivity rule and keeps the good message
(`ArgumentError` with `name: 'repeats'`, `message: 'must be positive'`). A new
test pins that contract; `--repeats=-2` is still rejected while parsing.

### 7. Duplicated evidence inventory between ticket 32 and the audit

**Fixed.** The canonical per-frame inventory is the
[`32-agent-windows-gui.md` Screenshot inventory](32-agent-windows-gui.md#screenshot-inventory).
The audit no longer restates twenty frame descriptions; it keeps the mapping
from each named B-GUI checkpoint to the frames that satisfy it, plus the facts a
prose-only reading would miss. Ticket 32's tracker comment is reduced to the
outcome, the environment and a pointer. Nothing was deleted from the ticket-32
report itself, because that report is the one description of record.

### 8. Accepted verdict only existed as untracked primary state

**Fixed.** This branch now tracks the files the gate points at, in the tracker's
own layout:

- `.scratch/trelis-backend-tracer-bullets/issues/31-platform-ci-native-evidence.md`
  — the platform/native ticket that ticket 33 is blocked by, previously only a
  file on the primary worktree's disk and therefore a dangling link;
- `.scratch/trelis-backend-implementation/issues/16-backend-evidence-gate.md` —
  the retained compatibility gate, with its mirrored accepted verdict;
- `.scratch/trelis-backend-implementation/spec.md` — the normative B-requirement
  text both of the above cite as their acceptance reference.

No other tracker file was added. The remaining `.scratch` links that point at
other efforts' planning documents (`../trelis-theming/…`,
`../trelis-theme-integration/…`, `dependencies.md`) are unchanged references to
material outside this branch's scope, and `tool/check_doc_links.dart` excludes
dot-directories, so they are not part of the documentation-link gate.

### 12. Functional fixes made under evidence tickets

**Documented, not rolled back.** Ticket 32 and ticket 33 were evidence tickets,
but reaching a *checkable* checkpoint required product changes. Each one is
mapped to the acceptance clause it serves:

| Change | Commit | Why acceptance required it |
| --- | --- | --- |
| Session-owned help keeps paragraph breaks and clears the draft row | `429526b` | Without it the captured help screen showed a literal `\u{000A}` and a draft row painted over the help block, so B-MODAL's "dismissal restores the latest composite" could not be observed at all. |
| The visible session declares its terminal profile | `2ec0f94` | The probe otherwise advertised a profile the visible terminal could not honour, so the "expected versus observed" note would have compared two different renderings. |
| The probe drives concurrent feedback deterministically | `a598c8e` | B-GUI requires concurrent feedback under editing; a wall clock made the interleaving unreproducible for both the visible run and the scripted cross-check. |
| The probe exposes repeated and required-value runs | `46e1a6e` | The repeated-session and genuine-rejection checkpoints had no way to be produced through the public API. |
| A visible run can quieten its concurrent writes | `b94efda` | A still frame of the narrow/ASCII checkpoints is unreadable while writes scroll; the quiet path makes those frames evidence instead of noise. |

None of these changes behaviour the gate claims as new capability; they remove
obstacles that made the named checkpoints unobservable, and each is covered by
the scripted suites and the fresh matrix below.

## Spec findings

### 9. B-RESIZE's production seam was unreachable

**Confirmed and fixed** in
`feat(terminal-io): observe native console resize while idle`.

The finding was accurate: `TerminalResizeObserver` was a public seam with a
complete consumer, but no shipped transport implemented
`TerminalIoResizeObserver`, and the native transports built their own
`ScriptedInput`, so an idle resize could only be noticed by a keystroke.

`lib/src/native_resize.dart` now provides
`NativeConsoleResizeObserver` over the console a prompt actually paints to
(`Stdout.hasTerminal`/`terminalColumns`/`terminalLines`, the same facts the
launch profile uses). Both native transports supply it:

- **POSIX** forwards `SIGWINCH` as a notification hint;
- **Windows** has no resize event a prompt can watch without consuming the input
  records it also reads, so it relies on the bounded 250 ms fallback poll that
  the prompt already owns.

Both read the dimensions again after a hint, because a notification is not
geometry. Unknown, zero, negative and throwing reads return "unusable" instead of
fabricating a viewport; the prompt's watcher keeps coalescing identical
observations and cancelling its timer and subscription at every supported exit.

Evidence:

- `test/native_resize_test.dart` — observer semantics, unusable readings, the
  console read for attached/redirected/failing output, the bounded cadence, the
  platform notification source, and a public-seam test that a **poll-only**
  observation reflows an idle rich prompt (`> <…` windowed at 30 columns) with
  no key sent;
- `test/idle_text_input_resize_test.dart` — unchanged: coalescing, unknown/zero/
  throwing observations, one opening event, cancellation at prompt exit;
- native Windows: a new `resize` scenario in `test/text_input_windows.ps1`
  shrinks the real console buffer from 120x30 to 40x20 through Win32
  `SetConsoleWindowInfo`/`SetConsoleScreenBufferSize` with **no key injected**,
  then requires the draft row to be windowed inside 40 cells before submitting;
- POSIX/CI: a new `resize` scenario in `test/posix_terminal_pty.py` resizes the
  PTY to 30 columns, delivers the window change, waits for the overflow marker,
  then submits.

### 10. B-RESIZE evidence attribution

**Fixed.** The console attribute-restoration strings
(`503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`) evidence B-FAIL's acquisition and
restoration clause, not resize. They are gone from the B-RESIZE row and from the
ticket-08 report's resize claim, and remain where they belong: B-FAIL and the
platform evidence.

### 11. The doc-link count contradiction

**Fixed.** Ticket 33 cited `224` links at the accepted revision while the audit
and the matrix job report `Checked 244 relative links in 58 Markdown files.` at
that same revision. `244` is what the tool printed; ticket 33 now says `244`.

## Validation at this revision

| Command | Actual result |
| --- | --- |
| `dart test test/gui_evidence_probe_test.dart test/native_resize_test.dart test/idle_text_input_resize_test.dart --reporter expanded` | `+16: All tests passed!` |
| `dart test --reporter compact` | `+961: All tests passed!` (one earlier run of the same tree reported one failure in `cron_interaction_conformance_test.dart`, a file this branch does not touch; see limitations) |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 154 files (0 changed)` |
| `dart analyze` | `No issues found!` |
''s re-verification table |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario resize -Report …` | `text input resize PASS result=0123456789…456789 state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1` (repeated: one run measured the state before the prompt acquired, `503 -> 503 -> 503`, with the same PASS) |
| `.github/workflows/platform-regression.yml` | fresh six-job run [43747443317](https://github.com/louiss0/trelis/actions/runs/43747443317) at `324e3d7`, the final code revision: all six jobs `success`; each Dart job `Formatted 154 files (0 changed)`, `No issues found!`, `Checked 244 relative links in 58 Markdown files.`, `+961: All tests passed!`; both POSIX jobs printed all eleven PTY scenarios including `resize: PASS (0123456789…)`; the Windows job passed its eighteen console scenarios including `resize` plus six pseudoconsole cases |

## Limitations carried forward

- The visible GUI frames in `gui/` were captured at `b94efda3…`, before the
  native resize observation existed. They remain honest evidence of that
  revision, including its "no idle reflow" note; they are **not** re-captured
  here, and this branch claims live idle reflow from the native Windows console
  check and the POSIX CI check instead of from those frames. A future visible
  GUI run at this revision should show the reflow.
- Windows native checks inject console records and resize the console buffer
  directly; they are not physical keyboard or human-usability evidence.
- Linux/macOS native evidence is CI-only, as the platform contract allows.
- `cron_interaction_conformance_test.dart` is timing-sensitive: it asserts
  `Calculating preview` 40 ms and `Matching preview: cancelled` 150 ms after
  input, against a 2,000,000-iteration preview budget, so a loaded full-suite run
  can miss those windows. It is unchanged by this branch, passed 6/6 in
  isolation and on the other full runs, and is recorded here rather than
  retried until green.
