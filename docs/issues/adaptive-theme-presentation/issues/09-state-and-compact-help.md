# 09 Compose state indicators and compact help

Status: claimed

**Blocked by:** [08](08-text-input-tracer.md)

**What to build:** Implement and exercise reusable internal presentation primitives for composable states and essential help, using the tracer and representative renderers. Do not claim all families are migrated or accessibility-qualified; preserve public calls until cutover. Follow the [design](../../../adaptive-theme-accessibility-design.md) for exact state semantics and help behavior.

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(selectionStyle: SelectionStyle.circles);
final prompt = theme.textInput('Name');
final result = await prompt.prompt(); // Essential help accompanies the prompt.
```

## Acceptance criteria
- [ ] Test simultaneous focus, selection and default independently: Unicode `→`, `✓`/`○`, `★` and ASCII `>`, `x`/`-`, `D`; test all five single-selection styles and distinct ASCII pairs, including narrow layouts and monochrome.
- [ ] Test separate aligned tree disclosure (`▾`/`▸`, `v`/`>`, blank for leaves), textual status labels with symbols, and `[L]`/`[!]` with readable reasons; locked/unavailable choices remain focusable but cannot be selected or accepted.
- [ ] Show compact primary-action/help hints even with hidden instructions; rich bottom, normal linear after content, screen-reader essential text before prompt; no artificial feedback help. Reduce decoration before essential content on short screens.
- [ ] Detailed help preserves draft, focus and caret; test safe secret and key-capture routes, screen-reader sequential output and no secret disclosure. Cover unavailable help space and failed rendering without corrupting active state.
- [ ] Record automated test commands and results; document missing real-terminal visual and human screen-reader evidence rather than claiming accessibility qualification.
