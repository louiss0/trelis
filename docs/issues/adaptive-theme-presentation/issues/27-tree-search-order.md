# 27 Migrate tree, search and ordering prompts

Status: resolved

**Blocked by:** [26](26-boolean-and-basic-choices.md)

**What to build:** Migrate TreeSelect, Autocomplete, SearchSelect, SortableSelect and CommandPalette through the internal theme-owned presentation/session seams. Preserve public calls until coordinated cutover and follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Proposed examples — NOT IMPLEMENTED

```dart
final tree = RailTheme().treeSelect('Choose a node', nodes); // List<TreeNode<T>>
final choice = await tree.prompt();
```

```dart
final search = RailTheme().autocomplete('Find', suggestions: findSuggestions);
final first = await search.prompt();
final next = await search.prompt(); // Uses configured initial state again.
```

## Acceptance criteria

- [x] Test all five real components in rich, linear and screen-reader presentations, preserving choice, search, ordering, command and result types and operations.
- [x] Compose focus, selection and default states independently; show tree disclosure separately (`▾`/`▸`, ASCII `v`/`>`) with aligned blank leaf positions. Test ASCII and no-color, including narrow layouts.
- [x] Keep locked/unavailable choices focusable but unselectable with readable reasons; verify ordered selection, expansion and search states remain understandable without color and are described textually to screen readers.
- [x] Show mandatory compact primary-action/help hints in rich bottom and normal linear after content; show essential screen-reader instructions before each prompt even when instructions are hidden. Help preserves query, draft, focus, caret, tree and ordering state as applicable.
- [x] Verify editable search safety independently: escaped or identified pasted command-shaped input survives invalid retry, help/cancel remain available under short value limits, and recognized multiline paste into single-line fields is rejected without losing the draft; safely manage paste reporting where applicable.
- [x] Exercise asynchronous searches for stale, failed and recovered results, cancellation and cleanup, without corrupting current query or allowing late results to overwrite newer state.
- [x] Preserve internal delegation through the same theme owner without triggering the external concurrent-prompt guard; retain theme-wide interaction, color and selection settings.
- [x] Test accepted, rejected/retried, cancelled, interrupted, unavailable and `InputEnded` outcomes, plus sequential reuse from configured initial values and rejection of concurrent prompts.
- [x] Record automated test commands/results and missing native or human screen-reader evidence; do not infer accessibility qualification from scripted tests.

## Comments

Implemented the internal `theme_tree_search_components.dart` seam with a
theme-owned `ThemeSession` for `TreeSelect`, `SortableSelect`, `Autocomplete`,
`SearchSelect` and `CommandPalette`. The real components gained an optional
`presentation` configuration only; existing public calls and result types are
unchanged until the coordinated cutover. Tree disclosure, order position and
movement, restriction reasons, and response-local candidate positions reuse the
shared state/help vocabulary. Hidden-instruction search and autocomplete
guidance now retains the primary action as well as the help route.

Validation (all run in this worktree):

- `dart test test/theme_tree_search_presentation_test.dart` — 5 passed.
- `dart test test/theme_tree_search_components_test.dart` — 14 passed.
- `dart test test/tree_select_test.dart test/sortable_select_test.dart test/autocomplete_test.dart test/search_select_test.dart test/command_palette_test.dart test/async_search_migration_test.dart test/tree_order_migration_test.dart` — 123 passed.
- `dart test -r compact` — 5481 passed.
- `dart format --output=none --set-exit-if-changed .` — no files changed.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 tracker files checked, no legacy local tracker.

Decisions: autocomplete candidates remain response-local (positions, never
stable references); the theme supplies glyphs, selection style and restrictions
while I/O, interaction and colours stay owned by one active period; no generated
files or public API inventory were changed.

Evidence limits: all checks are scripted/synthetic. No native terminal,
actual screen-reader, real light/dark visual, bracketed-paste native behaviour
or human accessibility qualification was performed here; those remain gates
37, 38, 41 and 42 and are not implied by these results.
