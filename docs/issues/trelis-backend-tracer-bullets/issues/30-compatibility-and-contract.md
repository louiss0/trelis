# 30: Complete compatibility checks and retire migrated legacy paths

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Finish the expand–migrate–contract transition with the complete public component surface working on the shared backend.

**Blocked by:**
- [17: Isolate region faults and recover safely from session failures](17-session-failure-recovery.md)
- [18: Migrate Password and URLInput without private-state leakage](18-private-entry-migration.md)
- [19: Migrate Confirm, Checkbox and Toggle](19-boolean-migration.md)
- [20: Migrate Multiline and TagInput](20-multiline-tag-migration.md)
- [22: Migrate TreeSelect and SortableSelect](22-tree-order-migration.md)
- [23: Migrate asynchronous suggestions and search](23-async-search-migration.md)
- [24: Migrate formatted-value inputs](24-formatted-values-migration.md)
- [25: Migrate DateInput and TimeInput](25-date-time-migration.md)
- [26: Migrate sliders, ranges and MaskedInput](26-range-mask-migration.md)
- [27: Migrate path entry and filesystem browsing](27-filesystem-migration.md)
- [28: Migrate CronInput entry, preview and review](28-cron-workflow-migration.md)
- [29: Migrate Keypress and KeyChordInput](29-key-capture-migration.md)

**Status:** resolved (ticket/backend-30-compatibility-contract)

**Claim:** ticket/backend-30-compatibility-contract worktree; compatibility audit, internal-projection repair and final evidence complete on `c3e03ee` (documentation commits only after it).

**Acceptance reference:** [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-SECRET](../../trelis-backend-implementation/spec.md#b-secret).

- [x] Verify all 34 interactive and four feedback components, deep outcomes/callbacks/defaults and complete help/protected-content coverage.
- [x] Compile/check invocation and constructor compatibility against the approved inventory and document intentional plain/profile/instruction migrations.
- [x] Delete legacy implementations only after no live consumers remain; keep CI green through the contract step.
- [x] Review transcript changes semantically instead of blindly replacing snapshots, and retain secret/capture/async safeguards.
- [x] Publish accurate usage/migration guidance without package renaming or accessibility claims.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

**Open merge-validation follow-up carried forward:** the two path-length-dependent filesystem wrap assertions reported on ticket 27 are not repaired here; the merger's queued repair (`a0fc708f`) owns them. In `../prompty-backend-ticket-30` the same suite passed, confirming the path-length dependence rather than a functional regression.

Branch `ticket/backend-30-compatibility-contract` commits: `0012b2a` (public-surface contraction, Autocomplete identity repair, compatibility inventory, URLInput/TimezoneSelect help coverage), `c3e03ee` (three format-only test repairs), `577fcf3`/`83bb622`/`bcd25af` (README/CHANGELOG migration guidance and this report). The required merge reported `Already up to date` at integration tip `13b524b`, so the tested revision did not change.

**Merge validation (integration merger, `integration/trelis-backend-tracer-bullets`).** `ticket/backend-30-compatibility-contract` (`bcd25af`) merged with `git merge --no-ff` into integration tip `a1242c0`, producing merge commit `de7ed84` (parents `a1242c0`, `bcd25af`). `git merge` reported `Merge made by the 'ort' strategy` with no conflicts, `git diff --diff-filter=D HEAD^1 HEAD` is empty (no deletions), `git log HEAD..ticket/backend-30-compatibility-contract` is empty, and the change set matches the ticket diff exactly (14 files, 1130 insertions): the three format-only repairs, the internal projection contraction, the `Autocomplete` identity repair, the eight-test compatibility inventory and the URL/timezone help tests.

The integration lock `.git/pi-integration-merge.lock` was taken with an exclusive create, held across validation and the mutation checks, and released only by this merger. The queued filesystem repair (`a0fc708f`) had already landed as `a1242c0` on the integration tip before this merge, so nothing was overwritten or duplicated.

Dependency check: `pubspec.yaml` is byte-identical to the merge base (`git diff 13b524b HEAD -- pubspec.yaml` is empty), `termunicode` keeps the exact pin `0.2.0` in `pubspec.yaml` and resolves to `0.2.0` only (`termunicode 0.2.0 (0.3.0 available)`). `dart pub get` reported `Got dependencies!` and left the local lockfile untouched, and `pubspec.lock` is gitignored and untracked, so the worker's `Changed 54 dependencies!` was a fresh worktree resolving that lockfile rather than dependency churn from this ticket. No unrelated dependency change was accepted.

Validated on the merged tree (`de7ed84`), Windows NT 10.0.26200.0, Dart SDK 3.13.2:

| Command | Result |
| --- | --- |
| `dart pub get` | `Got dependencies!` (`termunicode 0.2.0`) |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 150 files (0 changed)` |
| `dart analyze` | `No issues found!` |
| `dart run tool/check_doc_links.dart` | `Checked 155 relative links in 59 Markdown files.` |
| `dart test` on the compatibility-inventory/async/help/secret/session/native-reader bundle (19 files) | 192 tests passed |
| `dart test test/public_compatibility_inventory_test.dart` | 8 tests passed |
| `dart test test/component_acceptance_matrix_test.dart` | 144 tests passed |
| `dart test --reporter compact` | 926 tests passed |
| Same full suite from a 116-character working directory | 926 tests passed |
| Path/filesystem bundle at workspace-path length 31 and at 116 | 60 tests passed at both lengths |

The wrap and flake diagnostics carried on tickets 27 and 30 are therefore repaired, not waived: `a1242c0` is on the integration tip, its parameterized short/long bases and `_displaySafeText` helper are present, the absence assertions use the refusal contract, and the filesystem suites pass at both path lengths.

Mutation checks on the merged tree, each restored afterwards and verified by blob hash against `HEAD` (`autocomplete.dart`, `prompty.dart`, `url_email_input.dart`, `search_select.dart`, `text_input.dart` all matched, working tree clean):

| Mutation | Outcome |
| --- | --- |
| Restore `reference: index` on the `Autocomplete` `candidateAccepted` event | `a response-local candidate acceptance has no source-stable reference` failed, `Expected: null / Actual: <1>` |
| Re-add the presentation projection export to `lib/prompty.dart` | The barrel export guard failed and named the added export |
| Weaken `helpText` to `Help: Enter a value` | `rich and linear Ctrl+T help describes URL entry without the draft` failed in both modes |
| Change `the canonical identity is returned` in the timezone help | `rich and linear help state the matching and identity rules` failed |
| Flip the documented `Password.mask` default to `true` | `documented defaults baseline constructor defaults are unchanged` failed |

**Merge-validation finding, not repaired here (assertion strength only, no current failure).** The new timezone help test compares a document with all whitespace collapsed, so a wrapped token can acquire a space: when the timezone help string was made longer by a mutation, the assertion failed on `no offset or c urrent time` rather than on its intended clause. Its `city names and aliases` assertion is also satisfied by the entry label printed outside help, so weakening only the help clause to `city names and dliases` still passed. With the committed text the test passes deterministically and the `Help: TimezoneSelect`, `canonical identity` and `no offset or current time` assertions do bite, so this is a hardening follow-up rather than a defect in this merge: strip line breaks instead of collapsing all whitespace (`_displaySafeText`, as in the ticket-27 repair) and anchor the matching phrase to the help text.

Tracked tree after the merge is clean apart from the pre-existing unstaged `GLOSSARY.md` modification and the pre-existing untracked root entries, all of which were left untouched; every existing worktree, including `../prompty-backend-ticket-30`, was left in place.

## Answer

Executed on Windows NT 10.0.26200.0 with Dart SDK 3.13.2 at `c3e03ee` (documentation only after it). `dart format --output=none --set-exit-if-changed .` reported `Formatted 150 files (0 changed)`, `dart analyze` reported `No issues found!`, `dart run tool/check_doc_links.dart` checked 155 links in 54 files, the full suite passed 923 tests, the acceptance matrix passed 144 tests and the targeted compatibility/help/secret/capture bundle passed 178 tests. Evidence is in `doc/evidence/trelis-backend/30-compatibility-and-contract.md`.

The contract step removed the accidental public export of `DisplayText` and the five query/results types: the typed projection is an internal presentation contract observed through the public transcript and can no longer be constructed by a consumer. `Autocomplete` linear interaction no longer records its response-local candidate ordinal in the source-stable `reference` slot. A compile-level inventory test now covers all 34 interactive and four feedback constructors, the shared invocation seam, preserved answer types/generics and the documented defaults, and pins the barrel's export list. `URLInput` and `TimezoneSelect` gained the component-help coverage they were missing (URL help in both modes without draft disclosure and the literal-`/help` exception; timezone stage help with matching rules, canonical identity and no offset/current-time claim, reachable under hidden instructions).

The legacy caller audit found no separate legacy implementation to delete: migrations replaced the pre-backend code in place, every retained compatibility surface (`supportsRich`, `Stdout`/`terminal:`/`outputProfile:`/`session:`, direct constructors, `ScriptedInput`) has live callers, and the internal compositor/projection scaffolding is kept deliberately for the theme phase rather than as dead code. No snapshot or golden was regenerated; the Autocomplete transcript change was reviewed semantically through an independent red-then-green assertion, and the secret, capture and async safeguards are unchanged and re-run.

No package or import was renamed and no accessibility claim is made. Native PTY, visible GUI/NVDA, Linux/macOS CI and the backend evidence gate remain outstanding for tickets 31, 32 and the gate, and the named-theme rollout stays blocked.
