# Ticket 23 — asynchronous suggestions and search evidence

**Status:** pass for the scripted public `Autocomplete`, `SearchSelect`,
`CommandPalette` and `TimezoneSelect` seams.

## Source and environment

- **Implementation revision:** `f83e7d1` (partial migration, preserved) advanced
  by this work; the merge revision and the exact re-run revision are recorded in
  the ticket's `## Answer` comment, which is written after
  `git merge integration/trelis-backend-tracer-bullets` reported its result.
- **Branch:** `ticket/backend-23-async-search-migration`, base
  `74c5171bdd794b69262558130aa64195b68ec57b`.
- **Date:** 2026-11-13
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable (`dart --version`).
- **Selected input/output:** synthetic `Stream<String>` input with `StringBuffer`
  output, one `SwitchableSink` that injects a selected-output failure, explicitly
  declared rich profiles (cursor support plus positive geometry) for rich
  scenarios, and one public `TerminalSession` scenario with a live feedback
  region.
- **Geometry/width policy:** default `TextDisplayMap` width policy at the
  declared 100x30 profile; colour not declared, so none is emitted.

## Public behavior exercised

`test/async_search_migration_test.dart` (24 tests) invokes only the public
constructors, `prompt` methods and the public `ScriptedInput.transcript`
recording seam. `test/search_select_test.dart` (34), `test/autocomplete_test.dart`
(32), `test/command_palette_test.dart` (7) and `test/timezone_select_test.dart`
(11) keep the previous task/outcome coverage and now drive their asynchronous
scenarios through `test/support/async_search_fixture.dart`; `test/native_async_fixture_test.dart`
(2) still replays the launchable native scenario fixtures.

### Typed query/results projection

- `QueryResultsPresentation` is built before any output and before any
  structural layout. It carries the component identity, the display-safe label
  and query, an explicit `QueryResultsPhase` (`idle`, `loading`, `ready`,
  `empty`, `failure`), the `QueryResultsIdentityModel`, the total result count,
  typed rows and typed notices.
- Source-stable components (`SearchSelect`, `CommandPalette`, `TimezoneSelect`)
  project `QueryResultsIdentityModel.sourceStableChoice` rows whose `reference`
  is the displayed source reference, unchanged by filtering, paging or a
  replaced response. `Autocomplete` projects
  `QueryResultsIdentityModel.responseLocalCandidate` rows whose `reference` is
  null and whose `position` is only an ordinal in the current response.
- Idle, loading, ready (non-empty), ready-empty and failure are distinct states:
  loading and failure report `canAccept == false`, an empty response is recorded
  as ready-empty rather than as a failure, and `retryAvailable` is true only for
  a failure, whose notice is `retryByEditing`. Unknown or duplicate response
  identities are recorded as the `invalidIdentities` notice together with
  `retryByEditing`.
- A response is rejected before projection when it is obsolete (a newer request
  exists) or the prompt has closed, so a late completion after `Cancelled`,
  `InputEnded` or a session teardown projects nothing and writes nothing. The
  recorded phase stays `loading` in those cases, and the painted output is
  byte-identical to the snapshot taken at closure.

### Meaningful, ordered events

`TextInputPresentationEventKind` gained four occurrence kinds — `results`,
`resultsFocused`, `candidateAccepted` and `rejected` — recorded into the existing
public `TextInputTranscript` with stable run-local ids:

- `results` carries the typed projection and is recorded only when the
  presentation facts change: a repaint, paging to the same page or a no-op key
  adds no history, while a fresh request for a new query is a new occurrence even
  when it fails with identical wording.
- `resultsFocused` marks the query-to-results transition, which is distinct from
  an acceptance: query-stage Enter in `SearchSelect` opens results and does not
  accept a choice, and `Autocomplete` free-text Enter records `submitted`
  without any `candidateAccepted`.
- `candidateAccepted` records a candidate or stable reference copied into the
  draft, with its reference where one exists; the prompt's own `PromptResult`
  remains the only statement of the final outcome.
- `rejected` records a refused action (a stale reference, an unavailable choice
  and its protected reason, an over-long candidate, rejected paste) so retry and
  refusal are observed facts rather than snapshot diffs.
- Help occurrences keep their previous identity behaviour: repeated help
  requests are separate occurrences, and an asynchronous result arriving while
  help owns the screen is recorded (and deferred) but not painted until
  dismissal.

### Component and stage help

- `_instructionIntro` applies `InstructionDisplay` truthfully: `hidden` keeps the
  label and the actual help route only, `compact` keeps one short stage line, and
  `themeDefault`/`expanded` keep the reference guidance. No policy removes help
  access, and a test iterates every policy in both modes.
- Help is evaluated when it is requested (new optional `liveHelpText` /
  `liveLinearHelpText` editor parameters) so asynchronous state is described
  truthfully instead of from a stale string captured when the editor opened.
- Help is stage- and component-specific: `SearchSelect` names the query stage
  (Enter opens results without accepting), the results stage (current result
  count, page, focused identity, unavailable count and its protected reason,
  `/search`, `/next`, `/previous`, `/list`) and the loading/failure/empty state
  with its retry rule; `Autocomplete` names the pending/ready/failure state, the
  candidate list, the response-local identity model and the `maxLength` limit;
  `CommandPalette` states that accepting a reference does not run it;
  `TimezoneSelect` states identifier/city/alias matching, the canonical identity
  and that no offset or current time is consulted. Supplementary help augments
  the built-in text rather than replacing it.
- Dismissal is safe: rich help dismissal restores the retained query draft, the
  focused result and the caret (verified by accepting the retained draft after
  help), and structured warnings that arrived during help are painted after
  dismissal.
- Wrapper behavior is unchanged: `CommandPalette` and `TimezoneSelect` forward
  source, mode, output profile and session to `SearchSelect`, reject competing
  session configuration through the shared session, still return `Unavailable`
  for an unsupportable explicit rich request, and `CommandPalette` accepts an
  identity without executing application work; `TimezoneSelect` returns the
  canonical zone for an alias and explains unavailable defaults.

### Deterministic async and selected-output faults

- `test/support/async_search_fixture.dart` releases each request explicitly
  (`PendingRequests`), pumps microtasks (`settle`, `settleUntil`) and fails loudly
  when an expected state is never reached. The only wall-clock wait is
  `awaitLoneEscape`, the shared editor's own 80 ms disambiguation timer for a
  lone Escape; every other ordering is microtask- or request-driven.
- Verified with those fixtures: obsolete success and obsolete error; late
  completions after cancellation and after input end; cancellation and EOF while
  a request is outstanding; results arriving while help owns the screen; the
  retained draft after help dismissal; concurrent feedback with an asynchronous
  result inside one `TerminalSession`.
- A `SwitchableSink` injects a selected-output failure while a request is
  outstanding. The prompt ends with the original injected error (it is not
  swallowed and not retried), and the sink records no further accepted output,
  because a detached continuation routes the failure through the prompt's reader
  instead of leaving an unhandled asynchronous error.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/presentation.dart lib/src/text_input.dart lib/src/autocomplete.dart lib/src/search_select.dart lib/prompty.dart test/async_search_migration_test.dart test/search_select_test.dart test/autocomplete_test.dart test/support/async_search_fixture.dart` | Passed: `Formatted 9 files (0 changed)` |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 154 relative links in 51 Markdown files.` |
| `dart test test/async_search_migration_test.dart test/search_select_test.dart test/autocomplete_test.dart test/command_palette_test.dart test/timezone_select_test.dart test/native_async_fixture_test.dart --reporter expanded` | Passed: 110 tests |
| `dart test --reporter compact` | Passed: 861 tests |

The whole-suite count includes the 837 tests that passed on `f83e7d1`; the 24
new tests are this ticket's projection, event, help and fault coverage. No
existing test was deleted or weakened, and no golden output was regenerated.

## Limitations

- This is deterministic scripted public-behavior evidence at the listed
  revision. It is not native PTY, visible-terminal, screen-reader, Linux/macOS CI,
  alternate-screen modal help, short-screen resize or final-backend-gate
  evidence; those remain owned by their dedicated tickets and the final audit.
  It makes no whole-library accessibility claim.
- Rich presentation is written to the transcript rather than an alternate
  screen, so vertical overflow is ordinary scrollback and only horizontal
  wrapping at the declared width was exercised.
- A lone Escape still costs the shared editor's 80 ms disambiguation wait; the
  fixtures await that timer explicitly instead of pretending it is absent.
- The help text for a large result set summarises protected reasons as a count
  (plus the focused reason) rather than listing every unavailable row, so a
  `TimezoneSelect` help request cannot emit hundreds of reasons.
- A failed selected output ends the prompt with the original error and the
  session then closes; isolating one region's writer fault from other live
  regions is still the shared-session ticket's contract, not this one's.
- `dart format --output=none --set-exit-if-changed .` reports three pre-existing
  unformatted files on the integration tip
  (`test/linear_text_input_events_test.dart`,
  `test/native_text_input_capabilities_test.dart`,
  `test/terminal_session_short_screen_test.dart`). They are unmodified here and
  belong to their own tickets.
