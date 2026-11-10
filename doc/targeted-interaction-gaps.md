# Targeted interaction gaps — closed

## Closure

Status: **closed at the user's direction**.

- All components have agent-executed interaction coverage, as confirmed by the
  user; the agent performed the interactions on the user's behalf.
- The specific async, identity/order, failure-presentation, casing and wording
  gaps are addressed by the implementation, regression tests and native checks
  recorded below. Analysis was clean and all 639 tests passed.
- The user reports that NVDA works properly across all components and that they
  found no NVDA problems. This is user-reported evidence, not a claim that the
  agent independently assessed NVDA speech.
- No additional physical-keyboard rerun or formal accessibility certification
  is required to close this targeted issue. The rendering/focus observations
  below are non-blocking follow-up notes, not unresolved acceptance gates.

Scope: follow-up to existing per-component manual interaction coverage, not a
restart of that coverage or a whole-library accessibility qualification.
Implementation baseline: `20e825a5d97fa6b05234a6b2c82d83d567801fc7`.

## Contracts under investigation

- **Async results:** Autocomplete and SearchSelect must ignore obsolete
  successes and failures, must not accept pending results, and must not write
  after the session closes. Controlled completion ordering is regression
  evidence; elapsed delays alone do not establish the order.
- **Returned identities/order:** SearchSelect retains source references and
  source ordering even when a callback reorders or relabels choices.
  MultiSelect returns source order, SortableSelect returns the chosen order,
  and TreeSelect returns the selected node identity, not its label.
- **Search failure:** a failed search is distinct from a successful empty
  search. Reviewing results must retain correction guidance. Editing the query
  starts a new request; this work does not add same-query retries.
- **Keypress casing:** preserve the source's logical letter casing, including
  declaration spelling. Do not infer casing from modifiers or normalize all
  letters. Modifiers and observed/declared/ambiguous provenance are separate
  facts. Lowercase scripted input and shifted uppercase Windows input are not
  contradictory expectations.
- **Protocol wording:** Autocomplete Tab accepts the first or active suggestion
  into editable text; Enter accepts an active suggestion, otherwise submits the
  text. SearchSelect query Enter enters results and result Enter accepts. These
  intentionally differ. Selecting a suggestion is not submission.

## Targeted checks and fixture use

- `test/search_select_test.dart` covers rich stale successes/errors, failure
  recovery, invalid callback identities, and relabelled/reordered callback
  results with stable source references. Existing linear stale-response tests
  remain in place.
- `test/autocomplete_test.dart` retains rich/linear stale-response regressions
  and checks obsolete errors, pending candidate acceptance, no writes from late
  success/error after submission/cancellation, and clarified rich instructions.
- `test/key_capture_test.dart` checks preserved uppercase/lowercase declaration
  spelling and ambiguous scripted capture. The existing Windows fixture checks
  shifted uppercase observed gestures; that native check was not rerun here.
- `test/native_async_fixture_test.dart` exercises the callbacks used by the
  native fixtures through public scripted prompts: Autocomplete stale results
  and SearchSelect failure/recovery. It is not a native terminal test.

Run `dart run test/autocomplete_native_app.dart stale` or
`dart run test/search_select_native_app.dart stale`, then type `a` followed by
`b`. The fixture delivers the obsolete `a` response after the `ab` response;
only **Current** should remain usable. In Autocomplete, inspect/accept the
candidate and then submit; in SearchSelect, enter results then accept identity
`b`. Replace `stale` with `failure`, type `fail`, then erase it and type `ok`
to recover to **Recovered**. These new scenarios use rich mode. Default fixture
invocations and the existing SearchSelect `linear` argument remain unchanged.
These opt-in scenarios were subsequently executed in a visible Windows Terminal
using agent-driven GUI keys; see the native follow-up below. This is not human
manual or NVDA qualification.

Existing native fixtures already expose the relevant exact returned values:
MultiSelect prints comma-joined returned identities (Windows expectation
`a,b`, source order), SortableSelect prints the returned permutation (`b,a`),
and TreeSelect prints the selected node identity (`b`). Their script assertions
are stronger than observing displayed labels alone; no replacement fixtures
were needed. These existing Windows assertions were rerun in their default rich
scenarios using `powershell -NoProfile -ExecutionPolicy Bypass -File
test/<component>_windows.ps1 -Report <temporary-report>`: all exited 0 and
reported PASS with exact results `a,b`, `b,a`, and `b`, respectively. Each ended
with its initial console state `503:7:25:1`. These are injected-console-record
checks, not human keyboard or NVDA evidence.

Validation for this increment on Windows: `dart analyze` reported no issues;
`dart test --reporter compact` reported **639 tests passed** after review fixes.
Focused runs also passed for SearchSelect/Autocomplete (42 before the final
three Autocomplete lifecycle regressions), Autocomplete alone (22 after those
additions), Keypress/KeyChordInput (18), and new fixture callback tests (2).
These are automated regression results only.

## Visible native follow-up

Executed at application revision `cabce2eb9db43f1260acca545887fbd50e49950d`,
Windows build 26200, Windows Terminal 1.24.12741.0, Windows PowerShell launched
with `-NoProfile`, Dart 3.13.2 windows_x64. All four fixtures used explicit rich
mode. Orca computer-use Windows provider 1.0.0 supplied synthetic GUI text/key
input to a visible terminal; screenshots, not the shallow accessibility tree or
the input API's success response, were used to verify outcomes. No reader was
used or qualified. Keyboard/layout and locale were not separately qualified.

| Fixture argument | Interaction and observed result | Retained screenshot |
| --- | --- | --- |
| Autocomplete `stale` | Type `a`, then `b`; Tab accepts `Current` into editable text; Enter returns `Current`. No obsolete candidate was accepted. | [result](evidence/async-native/autocomplete-stale.png) |
| Autocomplete `failure` | Type `fail`: `Suggestions unavailable.`; erase four characters, type `ok`, Tab then Enter returns `Recovered`. | [failure](evidence/async-native/autocomplete-failure.png), [recovery](evidence/async-native/autocomplete-recovered.png) |
| SearchSelect `stale` | Type `a`, then `b`; reference `2. Current` appears; Enter focuses results, second Enter accepts `Current`, returning identity `b`. | [result](evidence/async-native/search-stale.png) |
| SearchSelect `failure` | Type `fail`; Enter reviews zero results with persistent `Search unavailable; edit the query to retry.`; return to query, replace with `ok`; Enter then Enter accepts `Recovered`, returning identity `b`. | [failure review](evidence/async-native/search-failure-review.png), [recovery](evidence/async-native/search-recovered.png) |

All four returned to the PowerShell prompt. This is visual/native task evidence,
not a measured console-mode restoration check. Stale ordering is controlled by
the fixture implementation; the GUI alone does not measure completion times.

Observations/limitations retained rather than hidden:

- Async feedback sometimes adjoins the current input line: for example
  `> ab1 suggestions` and `> failSearch unavailable`. Outcomes passed, but this
  run does not establish clean draft/status rendering or reader usability.
- After entering failed SearchSelect results, attempting four Backspaces and
  typing `ok` did not replace the draft: it became `faok` and correctly could
  not be accepted. Recovery succeeded by Tab twice (results → Cancel → query),
  End, four Backspaces, `ok`, then Enter twice. The fixture's short recovery
  instructions assume query focus; use explicit focus traversal after review.
- No human keyboard, NVDA speech, linear variant, clipboard, IME or additional
  layout/platform behavior was exercised in this follow-up.

## Evidence boundaries

Public `prompt` outcomes and transcripts, and exact native-fixture result output,
are the agreed regression seams. Native injected console events are engineering
checks, not real keyboard, rendering or nonvisual usability evidence. Existing
manual interaction coverage is not invalidated by these targeted additions.

The user's confirmation of no NVDA problems across all components is recorded
in the closure above. A formal version-pinned accessibility qualification is a
separate claim, not a remaining blocker for this issue. Any future qualification
record should identify Windows Terminal, shell, NVDA/version/settings,
keyboard/layout, locale, mode, input protocol, exact application/backend
revision and sanitized task outcomes. Do not record secrets. Real
clipboard/IME/layout and Linux/macOS native evidence are not implied by Windows
or scripted passes. See
[ticket 31 evidence](ticket-31-regression-evidence.md) and the
[verification matrix](../.scratch/trelis-accessible-prompts/issues/11-verification-matrix.md).
