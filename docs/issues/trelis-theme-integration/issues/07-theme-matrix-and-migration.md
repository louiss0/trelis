# 07: Verify the full theme matrix and publish migration guidance

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Establish that every chosen structure works with every implemented component and publish accurate migration guidance for consumers.

**Blocked by:**
- [02: Deliver RailTheme and BranchTheme](02-rail-and-branch.md)
- [03: Deliver BoxTheme, RoundTheme and DoubleTheme](03-enclosure-themes.md)
- [04: Deliver MinimalTheme, AsciiTheme, ChevronTheme and BracketTheme](04-lightweight-heading-themes.md)
- [05: Deliver FormTheme, LedgerTheme and ColonTheme](05-form-ledger-colon.md)
- [06: Deliver LineTheme and BlockTheme](06-line-and-block.md)

**Status:** resolved

- [x] Verify all 570 typed factory pairs and at least 1,125 distinct applicable presentation/task paths, distinguishing mode-independent Text from live-feedback renderers.
- [x] Retain deep semantic/stage/help/secret/resize regressions; snapshots and supplied-answer-only validation cannot replace actual render/task paths.
- [x] Verify all 45 palette mappings and conversion independently, with cross-structure/per-component override integration rather than a redundant full palette Cartesian product.
- [x] Run current automated/CI-native checks and agent-operated representative Windows normal/narrow observations; Linux/macOS remain CI-only and no human gate is added.
- [x] Publish default/instruction/profile/session/synthetic-geometry migration guidance without package renaming or accessibility claims.
- [x] Reopen affected backend evidence if themes reveal a regression; publish an explicit accepted/blocked theme verdict with revision-linked artifacts.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

**Claim.** Claimed on `ticket/theme-07-theme-matrix` from integration revision
`2feac1ba216d3066fcd61dcaa48ac01328e657cf`
(`merge(themes): integrate line and block structural themes`). Tickets 02–06 are
resolved and merged, so this ticket is unblocked and all fifteen structures are
available to verify together. Will add the consolidated matrix, factory-surface
and palette verification fixtures on top of the merged work, publish the
migration guidance and the theme verdict, and resolve the ticket. No factory
signature, grammar or component behavior will change.

**Progress update.** Implemented and committed as verification on top of the
unchanged library:

- `test/theme_matrix_cases.dart` — the shared 34-component case table, moved out
  of the line/block framing suite so the component surface is declared once and
  both the per-ticket suites and the consolidated matrix use it. The moved table
  is byte-equivalent in behavior: the line/block suite still runs its 215 tests
  unchanged.
- `test/theme_matrix_test.dart` (1,264 tests) — the consolidated cross-product:
  1,020 interactive paths (34 components x 15 structures x 2 modes), 90 live
  feedback paths (Progress/Spinner/MultiSpinner x 15 x 2), 15 mode-independent
  `Text` paths, 105 cross-structure deep regressions, 30 representative normal
  (80-column) and narrow (24-column) observations and 3 matrix-evidence
  assertions. Every path is a real scripted render/task path that must complete
  its task, must show the stage heading in the structure's own spelling, and must
  show the structure's own decoration; each executed path is recorded and counted.
  The bytes of all fifteen structures across the whole interactive matrix are
  compared so no structure can pass as a colour-only clone.
- `test/theme_factory_surface_test.dart` (4 tests) — the 570-pair inventory: 38
  exact function-type typedefs, 15 typed tear-offs each, the runtime invocation of
  all 570 pairs with distinguishable non-default arguments, generics preserved and
  construction purity (no callback invoked, no output sink on any factory).
- `test/theme_palette_matrix_test.dart` (57 tests) — the 45 named palettes checked
  against the source atlas rather than the generated Dart: ten-role completeness,
  page-colour exclusion, selection mapping, the warning fallback, the declared
  terminal surface, conversion at every depth, the no-colour policy,
  `copyWith` immutability, whole-palette replacement, terminal-native defaults and
  an alternate palette across structurally different layouts with no neighbour
  leak.
- `doc/evidence/trelis-theme/migration.md` — migration guidance: Trelis name with
  unchanged package/import names, unchanged direct-constructor presentation,
  compact help and warning visibility, palette/default changes, profile/session
  options, explicit synthetic geometry for scripted rich output, the preserved
  value types and cancellation/interruption/EOF/unavailable distinctions, and the
  out-of-scope accessibility and universal-width qualifiers.
- `doc/evidence/trelis-theme/theme-07-matrix-evidence.md` — the evidence record and
  the explicit **accepted** theme verdict with revision-linked artifacts, plus the
  recorded limitations and one pre-existing, unrelated documentation-link
  condition.

**Verification at `HEAD` before merge** (Windows 11, Dart SDK 3.13.2):

- `dart format .` then `dart format --output=none --set-exit-if-changed .` → 0 changed (213 files).
- `dart analyze` → No issues found.
- `dart test` → +4795, all passed.
- `dart test` on the theme suites (`test/*theme*.dart`, excluding the shared case
  table) → +3834, all passed.
- `dart run tool/check_issue_tracker.dart` → 129 tracker files checked; no legacy
  local tracker remains.
- `dart run tool/check_doc_links.dart` → reports 34 broken links that all
  target pre-existing, unmigrated documentation; every target is absent at the
  integration base, and the two documents added here introduce none (see
  `doc/evidence/trelis-theme/theme-07-matrix-evidence.md`, section 6).
- `git status` → clean.

**Answer.** All acceptance bullets are satisfied. All fifteen namespaces expose
all 38 typed factories — 570 class-method pairs proven at compile time by exact
function-type tear-off maps and at run time by invoking every pair with
distinguishable non-default arguments — and 1,125 distinct applicable
presentation/task paths were executed: 1,020 interactive render/task paths, 90
live feedback lifecycle paths and 15 mode-independent `Text` presentations, with
each path required to complete its task and show its structure's own grammar, the
counts asserted from the executed set, and the fifteen structures proven distinct
so none is a colour-only clone; the deep stage/help/failure/secret/resize
regressions are retained and green per family with 105 further cross-structure
cases; the 45 named palettes were verified independently against the source atlas
with conversion, immutability, terminal-native defaults and cross-structure
override integration; the automated checks are green and the CI-only platform
coverage is recorded with the plain statement that no native-terminal visual
qualification was performed; migration guidance is published without package
renaming or accessibility claims. The verdict is **accepted**, no theme regression
surfaced, and no backend evidence gate is reopened. The worktree is clean and the
ticket is ready for merge.
