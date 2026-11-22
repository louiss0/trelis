# Ticket 22 — TreeSelect and SortableSelect migration evidence

**Status:** pass for the scripted public tree and order prompt seams.

## Source and environment

- **Implementation revision:** `99c6fa655f72ddb7b94bf4761d0b315f1c371d99`
  (README/documentation commit) on `ticket/backend-22-tree-order-migration`.
  The code is unchanged after `4100722`. The commands below were re-run at the
  branch tip immediately before this report was written; every commit after
  `99c6fa6` changes only this evidence file, so that tip's `lib/` and `test/`
  content is identical to the recorded revision.
- **Branch history:** `d956cd7` moves the two families into
  `lib/src/tree_order.dart` (behaviour-preserving part move), `07c4205`
  shared-profile/session/terminal migration, `fb2eeff` typed shared rows,
  `104fe9c` stage-led help, `0b5697f` background-repaint registration,
  `f4b943b` idle resize, `4100722` colour/outcome/failure coverage and
  `99c6fa6` documentation. The original help slice `ace39d1` is preserved and
  extended rather than reverted.
- **Base and merge:** based on integration `74c5171`; `git merge
  integration/trelis-backend-tracer-bullets` reported `Already up to date.`, so
  the integration tip was unchanged when this report was written.
- **Date:** 2026-11-13.
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable (`Tue Aug 25 01:01:12 2026 -0700`), commands run in the
  worktree `prompty-backend-ticket-22`.
- **Input/output:** synthetic scripted string streams and `StringBuffer`
  output, plus public `TerminalSession.run`, `Spinner`, `ScriptedInput`,
  `OutputProfile`, `ColorTheme`, `TerminalResizeObserver`, `TerminalIo` and the
  typed `PromptResult` observations. One failing `StringSink` injects a shared
  writer fault.
- **Profiles:** explicitly declared rich 40×8, colour-enabled 80×20 with
  `ColorDepth.indexed256`, and narrow 24×6 profiles; a 30×8 observation is
  delivered through the resize observer. No geometry is read from the host
  terminal and no test depends on the developer's locale or environment.

## Public behavior exercised

`test/tree_order_migration_test.dart` (21 tests) drives only the public
`TreeSelect<T>`/`TreeNode<T>`/`SortableSelect<T>` constructors and `prompt`, and
records that:

- the resolved output profile follows invocation/source precedence: a declared
  rich profile is honoured even when the legacy rich hint is false, an
  explicitly requested rich mode without declared cursor support and positive
  geometry is `Unavailable`, and `automatic` mode falls back to linear entry;
- a tree prompt keeps expansion and selectability independent — entering a
  branch never accepts it, a selectable branch can still be opened, a leaf may
  be unselectable, and an unresolved branch is never treated as an invented
  leaf; full displayed paths, the linear current path (`Path: root`), the
  nested default and the preorder references that stay stable while branches
  open and close are preserved, and a node the `isCurrent` check rejects is
  reported as no longer available instead of being replaced;
- an order prompt keeps locked anchors (visible reason, original position,
  never crossed), pick-up and drop, Up/Down movement while picked up, Escape
  reverting the current move before cancelling, and final submission only on a
  completed action;
- both families compose every row through the shared typed choice row, so the
  tree extension (path, expansion state, selectability, staleness) and the
  order extension (position of count, focus, locked reason, pick-up) stay
  separate facts; at a 24-column declared width the path wraps while
  `[collapsed]`, `[selectable]`, `[unavailable: reason]`, `[position n of m]`,
  `[locked: reason]`, `[moving]` and the stable reference prefix are never
  split;
- component help leads with the requesting stage — `Help: Navigating the
  tree`, `Help: Choosing a node`, `Help: Entering a node reference`,
  `Help: Ordering the list`, `Help: Moving <label>`, `Help: Entering a
  reference`, `Help: Entering a destination position` — and keeps the current
  path, the displayed default, the preorder/stable-reference rule, the
  revert-versus-cancel rule and every non-acceptable node or locked anchor with
  its protected reason in the same block; `/help` in linear mode keeps the
  component text and appends the exact command spellings instead of replacing
  it;
- rich mode paints rows and notices only: the emitted transcript contains no
  cursor-addressing, erase-line, alternate-screen or caret sequence, so the
  caret and viewport stay owned by the shared editor in the modes that have
  one; the tree's effective profile follows an idle resize observation, so both
  rows and later help are re-wrapped at the observed width;
- a background `Spinner` update inside one `TerminalSession.run` scope writes
  the feedback line and repaints the live tree/order rows instead of leaving a
  stale frame, and the retained focus, expansion and picked-up identity survive
  the update;
- an idle resize notification repaints without editing or accepting state, is
  suppressed while help owns the screen, and the observation subscription is
  released on every supported exit;
- incomplete actions never accept: expansion or a pick-up without a completing
  Enter, and a `/choose` or `/move` chain whose reference or destination never
  arrives, end as `InputEnded`;
- every terminal outcome stays distinct for both families — `Accepted`,
  `Cancelled`, `Interrupted`, `InputEnded` (rich and linear) and `Unavailable`
  for a rich requirement without declared capability — and `SuppliedAnswer`
  remains a literal stable reference or anchor-respecting permutation;
- an explicit `TerminalIo` adapter is acquired and restored exactly once for a
  tree acceptance and an order cancellation;
- the component palette is used for the focused row, guidance, refusals and
  acceptance as distinct SGR roles when the declared profile permits colour, and
  `NO_COLOR` through the native-style adapter suppresses owned colour while the
  unavailable reason stays visible;
- a failed shared writer surfaces the original failure from an attached tree or
  order prompt, retires the scope so a late `Spinner` registration is rejected,
  and never reports an acceptance.

Existing `test/tree_select_test.dart` (15 tests) and
`test/sortable_select_test.dart` (6 tests) continue to cover the earlier tree and
order behaviour and now declare a synthetic rich profile wherever they request
rich interaction, per the shared profile contract. The one changed assertion is
the former placeholder help string `Help: TreeSelect`, which the stage-led
`Help: Entering a node reference` block replaces while still naming the stable
reference and selectability rules the `ace39d1` slice introduced.
`test/component_acceptance_matrix_test.dart` supplies rich and linear tree and
order tasks.

Implementation notes:

- `TreeSelect`/`TreeNode` and `SortableSelect` moved into
  `lib/src/tree_order.dart`, a part of the shared library, so this migration
  does not collide with other component migrations in `lib/src/text_input.dart`.
  The public library surface is unchanged.
- Both accept `terminal`, `outputProfile`, `session` and an optional
  `ColorTheme`; an attached prompt goes through `TerminalSession._promptRunner`
  and inherits session input, output, mode and profile, so competing invocation
  configuration is rejected rather than silently merged.
- Both call `OutputProfile.resolve(invocation:, source:, supportsRich:)` and
  `_constrainToObservedGeometry`, apply `NO_COLOR` through that resolved
  profile, refuse an explicitly requested rich mode the profile cannot support,
  and select rich only for `automatic`.
- `_ChoiceRow` gained the typed tree facts (`_TreeRowState`, selectability,
  children-unavailable reason, staleness) and order facts (position of count,
  locked reason, movement); marker order is selection, position, focus, default,
  tree state, selectability, lock, movement, unavailability, and the existing
  choice families are unchanged.
- Guidance and notices use `_writeWrappedText` at
  `_textInputWidth(effectiveProfile)` recomputed per write, so a resize repaint
  re-wraps. `_watchIdleResize` (shared) provides the idle repaint and its stop
  callback runs on every exit.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/tree_order.dart lib/src/text_input.dart test/tree_order_migration_test.dart test/tree_select_test.dart test/sortable_select_test.dart` | Passed: `Formatted 5 files (0 changed)`. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 153 relative links in 50 Markdown files.` |
| `dart test test/tree_order_migration_test.dart test/tree_select_test.dart test/sortable_select_test.dart --reporter compact` | Passed: 42 tests. |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | Passed: 144 tests. |
| `dart test --reporter compact` | Passed: 835 tests. |
| `git merge integration/trelis-backend-tracer-bullets` | `Already up to date.` |

Red-before-green was observed for each implementation slice: the refusal of
undeclared rich output, the 24-column marker wrapping, the stage-led help
strings, the missing background repaint and the missing idle-resize repaint each
failed before the code changed. The resize-width fix was additionally re-checked
by temporarily restoring the stale width: the strengthened test failed
(`post-resize line exceeds the observed width`) and passed again after the fix.
The colour, outcome, incomplete-action and shared-writer-failure tests were
added after their shared plumbing already existed, so those four are coverage
tests rather than red-first slices; their assertions were not weakened to fit
the implementation.

The repository-wide `dart format --output=none --set-exit-if-changed .` reports
three changed files (`test/linear_text_input_events_test.dart`,
`test/native_text_input_capabilities_test.dart`,
`test/terminal_session_short_screen_test.dart`). They are unmodified by this
ticket (`git diff --name-only 74c5171..HEAD` lists none of them) and already
failed that check on the integration tip `74c5171`, so the failure is recorded
instead of reformatting unrelated files.

## Limitations

- This is deterministic scripted public-behavior evidence. It is not native
  terminal or PTY evidence, not visible-terminal GUI or NVDA evidence, and not
  Linux/macOS CI evidence; those remain owned by tickets 31, 32 and the final
  evidence gate. No human usability or whole-library accessibility claim is
  made.
- **Atomic markers wider than the declared width overflow it.** Wrapping keeps a
  state marker or reason in one piece, so a marker such as
  `[unavailable: offline]` (22 cells) cannot be split and exceeds a declared
  width narrower than itself. The wrap test therefore uses a 24-column profile,
  and a narrower declaration is not claimed to be overflow-free.
- **Wrapping is by display cell, not word boundary**, so help and guidance prose
  can be split mid-word; the assertions reconstruct logical lines instead of
  assuming word wrapping. This is the shared `_writeWrappedText` behaviour, not
  a tree/order behaviour.
- The shared editor's own sequential status lines (`Current text:` /
  `Cursor position:`) are not width-wrapped; they are owned by the text-input
  tickets, so the narrow-width measurement excludes exactly those lines.
- **Rich vertical overflow** is only observable as transcript scrollback; these
  tests assert line widths and retained state, not a scrolled live viewport.
- **Lone trailing Escape** in a scripted stream reports `InputEnded` because the
  escape disambiguation timer is cancelled when the stream closes, so the
  cancellation evidence sends `ESC` followed by another byte.
- **Rich help is a transcript block, not a modal screen:** the rich fixtures
  declare cursor support but not alternate-screen support, so alternate-screen
  modal help is not exercised for this family.
- **The resize observer contract is unchanged:** the observer's `notifications`
  stream must support repeated listens (a broadcast stream, as used by the
  fixtures). The native adapter that supplies it is not verified here.
- **Colour coverage is limited to indexed256 SGR emission:** truecolour,
  reduced-depth approximation, component-local backgrounds and style
  restoration are shared-module concerns covered by their own tickets, not
  re-verified here.
- Existing families still disagree about padded supplied references (`int.parse`
  tolerance); this migration preserves each family's current behaviour rather
  than changing public results.
