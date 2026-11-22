# 23: Migrate asynchronous suggestions and search

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use Autocomplete, SearchSelect, CommandPalette and TimezoneSelect without stale responses or misleading acceptance.

**Blocked by:**
- [21: Migrate Select, Radio and MultiSelect](21-selection-migration.md)

**Status:** resolved

**Claim:** ticket/backend-23-async-search-migration worktree; implementation and evidence complete on `c6579cb`.

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Preserve idle/loading/ready-empty/failure, focus transitions and actual query/retry rules.
- [x] Reject obsolete/closed-session callbacks before projection; distinguish source-stable choices from response-local candidates.
- [x] Retain candidate acceptance versus free-text submission and query-to-results transitions.
- [x] Provide component/stage-specific help with safe dismissal and unchanged wrapper/domain behavior.
- [x] Verify public rich/linear, errors/EOF/cancel, late completions and concurrent feedback cases with deterministic async fixtures.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Preserved the partial migration committed on this branch as `f83e7d1` and built
on it in `0c178a5` (typed projection, recorded events, live stage help,
deterministic fixtures, selected-output faults), `766bbed` and `64227f3`
(executed verification counts, implementation revision), `4eb63a8` (rich
feedback alongside an async suggestion response) and `c6579cb` (re-run revision,
documentation only). `git merge integration/trelis-backend-tracer-bullets`
reported `Already up to date.` before each report; the integration tip had not
moved from `74c5171`, so no integration commit is merged and the root branch is
untouched.

Integration merge (exclusive `.git/pi-integration-merge.lock` held from before
the mutation through the test runs): `git merge --no-ff
ticket/backend-23-async-search-migration` on
`integration/trelis-backend-tracer-bullets` created
`13b524b299b33c2dfc8fd03cff819dd02a483d7c` with parents `0c219fa`
(integration) and `c6579cb` (ticket tip). **No conflicts were reported**: `ort`
auto-merged `README.md` and `lib/src/text_input.dart`, and the remaining 16
paths applied cleanly. Retained after the merge, by inspection plus the suites
below: the native key reader and capture path (`_Capture`, native console
reader ownership), the guarded shared writer and its session retirement
(`retire()`, `_retireFeedback`, "a failed shared writer retires every
registration"), `tree_order.dart`'s `_ChoiceRow` and stage-led tree/order help,
and this ticket's live help additions (`liveHelpText`, `liveLinearHelpText`,
`onHelpDismissed`, `onHelpVisibilityChanged`). Unrelated root work was left
alone: `GLOSSARY.md` stays modified and the untracked `AGENTS.md`, `docs/`,
`docs/issues/` and `assets/research/` entries stay uncommitted.

Re-run in the integration worktree at `13b524b`: the six async/search/palette/
timezone/native-fixture suites passed 111 tests (reproducing the ticket figure),
`test/native_text_input_capabilities_test.dart` passed 4, and
`test/terminal_session_failure_recovery_test.dart` passed 15 (130 together);
`dart analyze` reported `No issues found!`; the changed files are formatting
clean (`Formatted 14 files (0 changed)`);
`dart run tool/check_doc_links.dart` passed 154 links in 58 files. The full
suite passed 908 of 910: the two failures (`test/path_input_behavior_test.dart`
expecting `Target must exist`, `test/filesystem_migration_test.dart` expecting
`no link canonicalization`) are pre-existing on the integration tip, not merge
artifacts — `lib/src/path_input.dart` already says `Existing target required` at
`0c219fa`, and `git diff 0c219fa 13b524b` is empty for those test files, the
implementation and every path/browser file. `test/support/
async_search_fixture.dart` has no independent tests; it is exercised through the
suites above.

Open review flag, deliberately not resolved by the merge: `lib/prompty.dart`
now exports six `src/presentation.dart` names (`DisplayText`, `QueryResultRow`,
`QueryResultsIdentityModel`, `QueryResultsNotice`, `QueryResultsPhase`,
`QueryResultsPresentation`). That library documents itself as internal, and the
approved boundary (`docs/issues/trelis-theming/issues/02`, `06`) keeps the
presentation vocabulary internal and defers public authoring, while every other
presentation type (`TextInputPresentationContent`, `PresentationDeclaration`,
`PresentationSlot`, `TextInputEditableRegion`) stays unexported. It is load
bearing for this ticket's evidence — `test/async_search_migration_test.dart`
names those types through `package:prompty/prompty.dart` and
`TextInputPresentationEvent.results` is typed by one — and the public
constructor lets a consumer fabricate a projection the boundary assigns to
behavior, so ratifying or narrowing it needs a contract decision, not a merge
resolution. Related concrete mismatch: `TextInputPresentationEvent.reference`
is documented as "the displayed source-stable reference", but
`Autocomplete`'s rich acceptance records a response-local ordinal there
(`lib/src/autocomplete.dart:324`) with nothing on the event distinguishing it
from `SearchSelect`'s source-stable `index + 1`; the distinction is only visible
through a `results` event's `identityModel`. The intended identity split itself
is preserved: `_candidateProjection` leaves `QueryResultRow.reference` null and
`position` local, while `SearchSelect`, `CommandPalette` and `TimezoneSelect`
project source-stable references.

## Answer

`Autocomplete`, `SearchSelect`, `CommandPalette` and `TimezoneSelect` now produce
an immutable `QueryResultsPresentation` before any output or layout: explicit
`idle`, `loading`, `ready`, `ready-empty` and `failure` phases, an explicit
identity model (source-stable choice references for the three choice families,
response-local candidates for `Autocomplete`, where a position is only an ordinal
in the current response), display-safe typed rows and typed notices for invalid
identities, retry-by-editing and a removed focused result. Obsolete and
closed-session responses are rejected before projection, so a late completion
after cancellation, input end or a session teardown projects and writes nothing.

The public `TextInputTranscript` records `results` (with the typed projection),
`resultsFocused`, `candidateAccepted` and `rejected` occurrences next to the
existing help/validation/outcome events, with stable run-local ids. Repaints and
no-op keys add no history, repeated identical failures remain distinct
occurrences, query-stage Enter is recorded as opening results rather than
accepting a choice, and free-text submission is never recorded as a candidate
acceptance; the prompt's `PromptResult` remains the only statement of the final
outcome. A detached continuation that cannot repaint ends the prompt with its
original error instead of leaving an unhandled asynchronous error.

Component and stage help is evaluated when help is requested, so it describes the
current asynchronous state: result count, page, focused identity, unavailable
count and protected reason, and the retry rule for `SearchSelect`; pending/ready/
failure state, candidate list, response-local identity and `maxLength` for
`Autocomplete`; no-execution acceptance for `CommandPalette`; canonical-identity,
alias-matching and no-offset-preview rules for `TimezoneSelect`. Every
`InstructionDisplay` policy keeps help access, supplementary help augments the
built-in text, and rich help dismissal restores the draft, focused result and
caret.

On Windows (NT 10.0.26200.0) with Dart SDK 3.13.2 at `4eb63a8` (`c6579cb` is
documentation only), the async-search suites passed 111 tests (25 new migration
tests), the full suite passed 862 tests, `dart analyze` reported no issues, the
changed files are formatting-clean and the documentation-link check passed 154
links in 51 files. Asynchronous scenarios release requests through
`test/support/async_search_fixture.dart` instead of sleeping; the only wall-clock
wait left is the shared editor's own 80 ms lone-Escape disambiguation timer. Evidence and limitations are recorded in
`assets/evidence/trelis-backend/23-async-search-migration.md`; native PTY, visible
GUI/NVDA, Linux/macOS CI, alternate-screen modal help, short-screen resize and
final-gate verification remain outstanding, help summarises protected reasons as
a count for large result sets, and region-level isolation of a failed writer
remains the shared-session ticket's contract.
