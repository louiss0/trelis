# Targeted interaction gaps

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
These opt-in native scenarios have not been manually executed in this increment.

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

## Evidence boundaries

Public `prompt` outcomes and transcripts, and exact native-fixture result output,
are the agreed regression seams. Native injected console events are engineering
checks, not real keyboard, rendering or nonvisual usability evidence. Existing
manual interaction coverage is not invalidated by these targeted additions.

Human/NVDA evidence stays separate and pending unless actually supplied. Record
Windows Terminal, shell, NVDA/version/settings, keyboard/layout, locale, mode,
input protocol, exact application/backend revision and sanitized task outcomes.
Do not record secrets. Real clipboard/IME/layout and Linux/macOS native evidence
are not implied by Windows or scripted passes. See
[ticket 31 evidence](ticket-31-regression-evidence.md) and the
[verification matrix](../.scratch/trelis-accessible-prompts/issues/11-verification-matrix.md).
