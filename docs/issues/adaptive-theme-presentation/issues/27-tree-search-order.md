# 27 Migrate tree, search and ordering prompts

Status: ready-for-agent

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

- [ ] Test all five real components in rich, linear and screen-reader presentations, preserving choice, search, ordering, command and result types and operations.
- [ ] Compose focus, selection and default states independently; show tree disclosure separately (`▾`/`▸`, ASCII `v`/`>`) with aligned blank leaf positions. Test ASCII and no-color, including narrow layouts.
- [ ] Keep locked/unavailable choices focusable but unselectable with readable reasons; verify ordered selection, expansion and search states remain understandable without color and are described textually to screen readers.
- [ ] Show mandatory compact primary-action/help hints in rich bottom and normal linear after content; show essential screen-reader instructions before each prompt even when instructions are hidden. Help preserves query, draft, focus, caret, tree and ordering state as applicable.
- [ ] Verify editable search safety independently: escaped or identified pasted command-shaped input survives invalid retry, help/cancel remain available under short value limits, and recognized multiline paste into single-line fields is rejected without losing the draft; safely manage paste reporting where applicable.
- [ ] Exercise asynchronous searches for stale, failed and recovered results, cancellation and cleanup, without corrupting current query or allowing late results to overwrite newer state.
- [ ] Preserve internal delegation through the same theme owner without triggering the external concurrent-prompt guard; retain theme-wide interaction, color and selection settings.
- [ ] Test accepted, rejected/retried, cancelled, interrupted, unavailable and `InputEnded` outcomes, plus sequential reuse from configured initial values and rejection of concurrent prompts.
- [ ] Record automated test commands/results and missing native or human screen-reader evidence; do not infer accessibility qualification from scripted tests.
