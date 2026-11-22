# Ticket 07 evidence and theme verdict: the full matrix

**Verdict:** **ACCEPTED** — the fifteen Trelis structural themes are verified
together as a matrix at the revision recorded below.
**Source revision:** the commit that records this document on
`ticket/theme-07-theme-matrix`, over the verified test revision
`ee54b977bea5cafc1c1ae0d777cee7d54d2bd824`
**Integration base:** `2feac1ba216d3066fcd61dcaa48ac01328e657cf`
(`merge(themes): integrate line and block structural themes`)
**Environment:** Windows 11, Dart SDK 3.13.2 (stable), worktree
`C:\Users\bvlou\projects\prompty-theme-07`
**Ticket:** [07: Verify the full theme matrix and publish migration guidance](../../../docs/issues/trelis-theme-integration/issues/07-theme-matrix-and-migration.md)
**Migration guidance:** [migration.md](migration.md)

This document records what was actually executed and observed. It is evidence
about the merged themes, not an implementation of them, and no test pass is
claimed for anything listed here without the command that produced it.

## Verdict

**Accepted.** At the source revision above:

- all fifteen structural namespaces expose all 38 typed factories — 570
  class-method pairs, checked at compile time and invoked at run time;
- every one of the 1,125 required presentation/task paths was executed as a
  real render or task path, and no structure renders as a colour-only clone of
  another;
- all 45 named palettes map the source atlas independently, with ten-role
  completeness, page-colour exclusion, selection mapping and the documented
  warning fallback;
- the deep semantic/stage/help/secret/resize regressions are retained and green
  per family, and 105 additional cross-structure regressions pass;
- the full suite, formatting, static analysis and the issue-tracker boundary are
  green.

**No theme regression surfaced during this ticket, so no backend evidence gate
is reopened.** That is the expected outcome, and it is stated explicitly rather
than inferred: every per-family suite and every backend-facing component suite
in the repository still passes unchanged, and none of the bytes the merged
structures produced before this ticket changed. Nothing in this ticket modified
a factory signature, a grammar or a component behavior, so there is no
relaxation of an existing snapshot that could hide a backend regression.

## 1. Factory surface: 570 class-method pairs

`test/theme_factory_surface_test.dart` (4 tests) is the inventory.

- **Compile-time proof of 570 pairs.** For each of the 38 factories, one typedef
  declares that factory's exact function type (return type, generics, positional
  and named arguments), and one map assigns the tear-off from each of the fifteen
  namespaces with that typedef as the map's value type. 38 typedefs x 15
  tear-offs = 570 typed assignments. A namespace that dropped a method, widened
  a return type to a shared base class, lost a generic argument or renamed an
  argument would not compile.

  Replacing a typed method with a dynamic argument bag is not representable:
  the value type is the factory's own function type, so a `Function`-typed
  surface fails the assignment.

- **Runtime proof of forwarding.** Every one of the 570 pairs is invoked with
  non-default, distinguishable arguments (a patched palette, `compact`
  instructions, supplementary help, entity-specific values such as a mask, a
  minimum/maximum, a template list, an absolute picker base). The returned
  object is asserted to be the concrete component type, to carry the forwarded
  colour/instruction/help configuration, and to be configured with its own
  namespace's `PromptStructure`. The generic factories are additionally asserted
  to keep their type argument (`Select<String>`, `MultiSelect<String>`,
  `TreeSelect<String>`, `SearchSelect<String>`, `CommandPalette<String>`,
  `SortableSelect<String>`, `Radio<String>`).
- **Construction purity.** A validate callback, a suggestions callback and a
  convention provider are passed to the factories that accept them and are
  asserted never to be invoked; no factory takes an output sink, so construction
  cannot perform terminal I/O. The four feedback factories keep their narrower
  signature with no instruction parameters, which the typedefs enforce.
- The executed pair count is asserted (`570`), so the inventory cannot quietly
  shrink.

## 2. Presentation and task paths: 1,125

`test/theme_matrix_test.dart` (1,264 tests) is the consolidated matrix.
`test/theme_matrix_cases.dart` holds the shared 34-component case table; it is
the only component list in the theme suites, so a new component or structure is
added once.

| Category | Paths | Composition |
|---|---|---|
| Interactive components | **1,020** | 34 components x 15 structures x 2 modes |
| Live feedback | **90** | Progress, Spinner, MultiSpinner x 15 structures x 2 modes |
| Mode-independent Text | **15** | Text x 15 structures |
| **Total** | **1,125** | the required minimum |

Each interactive path:

- drives the component with scripted keys and requires the task to complete
  (`Accepted`, never `Unavailable`) — supplied-answer-only validation is not
  accepted as evidence of a rendered stage;
- requires a non-empty visible presentation that contains the stage heading in
  the structure's own spelling (including the console and band grammars'
  documented uppercase heading);
- requires the structure's own decoration in the stage: a rail/branch spine
  glyph, an enclosure corner, a heading decoration, a rule, a label band, a typed
  event label or the numbered ledger heading. The reference presentation and the
  unframed minimal grammar declare no decoration of their own, so their proof is
  the fingerprint comparison instead;
- requires any reported outcome/notice the component reports to stay visible.

The 1,125 paths are **recorded as they execute** and a final test asserts the
per-category counts and the total, so the counts in this table are measured
results rather than arithmetic in a document.

No structure is a colour-only clone: the bytes each of the fifteen structures
produced across all 1,020 interactive paths are compared, all fifteen
fingerprints are distinct, and each of the fourteen non-reference structures
differs from the reference presentation. The live feedback markers are distinct
for every structure that declares one (the reference presentation declares none).

## 3. Deep regressions retained

- The per-family deep suites that the earlier tickets delivered are unchanged
  and green: the framing suites for rail/branch, the enclosures, the lightweight
  heading grammars, form/ledger/colon, line/block, the structure framing and
  rendering suites, the fifteen factory suites and the fifteen acceptance-matrix
  suites, and the palette suites. Together they are 3,834 theme tests, all
  passing.
- Added cross-structure depth (105 tests, 7 per structure) in
  `test/theme_matrix_test.dart`: a masked secret is never echoed while the
  accepted value is preserved; a protected control character keeps its spelled
  form; an unavailable choice keeps its reason; the stage help route (`Ctrl+T`)
  is preserved; cancellation, interruption (both modes) and end of input stay
  distinct outcomes; a resize repaints the live row at the new width without
  opening a second stage or losing the draft; answer data is never
  case-transformed, including under the uppercasing heading grammars.
- No omitted or misplaced typed content: every interactive path asserts the
  component's own reported outcome text is present, and the secret/protected
  cases assert what must not appear.
- The line/block suite still pins the exact linear bytes of the thirteen
  structures delivered before it, and those pins pass unchanged; no other
  structure's bytes were touched, because no production file changed.

### Representative normal and narrow observation

The matrix fixture also observes one themed stage per structure at a **normal**
width (80 columns) and a **narrow** width (24 columns): 30 scripted observations
that assert every display row of every structure's stage fits the columns it was
opened with (each structure's widest row measured exactly 80 and exactly 24
respectively) and that the structure's own grammar is still present at both
widths. This is an agent-operated, scripted observation of visible output; it is
**not** a native-terminal visual qualification and no human looked at a terminal
rendering.

## 4. Palettes: 45 verified independently

`test/theme_palette_matrix_test.dart` (57 tests) derives its expectations from
the **source atlas** (`tool/generate_theme_atlas.py`), not from the
generated Dart file, so the mapping is checked against its origin.

- 45 atlas records are parsed, each with nine declared colours, and the 45 named
  presets are asserted to be exactly that set.
- Per palette: `foreground` is the atlas text colour, `background` the declared
  terminal surface (asserted **not** to be the atlas page colour whenever the two
  differ), `muted`, `accent`, `selectionForeground` the atlas selected
  foreground, `selectionBackground` the accent, `success`, `error`, `border` the
  atlas rule, and `warning` the accent — the documented fallback. All ten roles
  are present and none is left terminal-native in a preset.
- Conversion: an atlas colour converts at every declared depth (RGB pair, the
  indexed value, an ANSI-16 code), emits the default request at `none` and
  `automatic`, and `terminalStyledText` returns the text unchanged when the depth
  cannot express colour (the no-colour/redirected policy at the value level).
  Every palette's every role converts at every depth without throwing.
- Terminal-native defaults: `ColorThemes.terminalDefault` is native in all ten
  roles and styles nothing. No forced dark/light surface: a light preset and a
  dark preset each keep their own declared surface.
- Custom palettes and immutability: `copyWith` returns a new palette, leaves the
  preset and every unspecified role untouched; a whole custom `ColorTheme`
  replaces all ten roles; no global colour state exists.
- Cross-structure and per-component override integration (not a palette
  Cartesian product): the same alternate palette styles rail, box, ledger and
  block stages in RGB output, and two components with different palette
  overrides keep their own styling with no neighbour leak.

## 5. Automated and CI-native checks

Executed in the worktree at the verified revision:

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format .` then `dart format --output=none --set-exit-if-changed .` | 0 changed (213 files) |
| Static analysis | `dart analyze` | No issues found |
| Full suite | `dart test` | +4795, all passed |
| Theme suites | `dart test test/*theme*.dart` (excluding the shared case table) | +3834, all passed |
| Issue-tracker boundary | `dart run tool/check_issue_tracker.dart` | 129 tracker files checked; no legacy local tracker remains |
| Worktree | `git status` | clean |

**CI-native coverage** is what `.github/workflows/platform-regression.yml`
executes on push and pull request; no CI run was triggered from this worktree
during this ticket:

- `windows-latest`, `ubuntu-latest`, `macos-latest`: `dart pub get`,
  `dart format --output=none --set-exit-if-changed .`, `dart analyze`,
  `dart run tool/check_issue_tracker.dart`, `dart run tool/check_doc_links.dart`,
  `dart test --reporter expanded`.
- `ubuntu-latest`, `macos-latest`: `python3 test/posix_terminal_pty.py`.
- `windows-latest`: the native Windows scenario scripts (rich, linear, help,
  escape, interrupt, eof, error, repeat, session-retire, resize, redirected,
  dumb-auto) and the multiline pseudoconsole regression.

Linux and macOS remain **CI-only**: no physical access to either platform was
used, and none is required. The Windows observations in this ticket are scripted
and agent-visible only.

**Evidence limitations.** No native-terminal visual qualification was performed:
no human looked at a Windows Terminal (or any other) rendering of a themed
stage, and no NVDA/screen-reader observation was recorded for this ticket. The
evidence above is automated and scripted. It therefore supports no
accessibility, audible, or universal width/font claim — see the out-of-scope
section of the [migration guidance](migration.md).

## 6. Unrelated, pre-existing condition

`dart run tool/check_doc_links.dart` exits non-zero and reports 34 distinct
source/target pairs of broken relative links across the pre-existing
specifications, evidence and README files. Every target is documentation that
was never migrated into this repository, for example
`assets/research/trelis-output-capabilities-and-width.md` (linked from
`docs/issues/trelis-theming/spec.md`), `assets/evidence/trelis-backend/post-review-fixes.md`
(linked from the backend gate tickets) and `assets/terminal-backend.md` (linked from
`README.md`).

None of the targets exists at the integration base
`2feac1ba216d3066fcd61dcaa48ac01328e657cf`, and this branch modifies no
document other than the two evidence files it adds, so the breakage predates this
ticket and is outside its theme scope. It is recorded here rather than silently
fixed, because repairing unrelated specifications is not verification of the
themes, and 34 unrelated edits would obscure the theme evidence. The two
documents added by this ticket introduce no broken link: none of the 34 broken
sources is a file this ticket creates.

## Revision-linked artifacts

| Artifact | Path |
|---|---|
| Consolidated matrix fixture | `test/theme_matrix_test.dart` |
| Shared component case table | `test/theme_matrix_cases.dart` |
| Factory-surface inventory | `test/theme_factory_surface_test.dart` |
| Palette verification | `test/theme_palette_matrix_test.dart` |
| Migration guidance | `assets/evidence/trelis-theme/migration.md` |
| This evidence and verdict | `assets/evidence/trelis-theme/theme-07-matrix-evidence.md` |
| Ticket | `docs/issues/trelis-theme-integration/issues/07-theme-matrix-and-migration.md` |
| Integration base | `2feac1ba216d3066fcd61dcaa48ac01328e657cf` |
| Verified test revision | `ee54b977bea5cafc1c1ae0d777cee7d54d2bd824` (`test(theme): observe normal and narrow stage widths`) |
| Test history on this branch | `256f6e0` (matrix fixture), `3ebf3c8` (factory surface), `728630a` (palettes), `ee54b97` (normal and narrow widths) |
