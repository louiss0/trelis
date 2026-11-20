# 09 Compose state indicators and compact help

Status: resolved

**Blocked by:** [08](08-text-input-tracer.md)

**What to build:** Implement and exercise reusable internal presentation primitives for composable states and essential help, using the tracer and representative renderers. Do not claim all families are migrated or accessibility-qualified; preserve public calls until cutover. Follow the [design](../../../adaptive-theme-accessibility-design.md) for exact state semantics and help behavior.

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(selectionStyle: SelectionStyle.circles);
final prompt = theme.textInput('Name');
final result = await prompt.prompt(); // Essential help accompanies the prompt.
```

## Acceptance criteria
- [x] Test simultaneous focus, selection and default independently: Unicode `→`, `✓`/`○`, `★` and ASCII `>`, `x`/`-`, `D`; test all five single-selection styles and distinct ASCII pairs, including narrow layouts and monochrome.
- [x] Test separate aligned tree disclosure (`▾`/`▸`, `v`/`>`, blank for leaves), textual status labels with symbols, and `[L]`/`[!]` with readable reasons; locked/unavailable choices remain focusable but cannot be selected or accepted.
- [x] Show compact primary-action/help hints even with hidden instructions; rich bottom, normal linear after content, screen-reader essential text before prompt; no artificial feedback help. Reduce decoration before essential content on short screens.
- [x] Detailed help preserves draft, focus and caret; test safe secret and key-capture routes, screen-reader sequential output and no secret disclosure. Cover unavailable help space and failed rendering without corrupting active state.
- [x] Record automated test commands and results; document missing real-terminal visual and human screen-reader evidence rather than claiming accessibility qualification.

## Comments

Added internal, non-exported `lib/src/state_help_presentation.dart` primitives for independent Unicode/ASCII state markers, the five single-selection styles, aligned tree disclosure, textual statuses, `[L]`/`[!]` reasons, compact hint placement, short-screen reduction, and state-preserving help outcomes. The tracer now accepts an instruction policy and emits sequential essential text before screen-reader prompts. `InstructionDisplay.hidden` keeps the primary action and help route; the README documents that observable change. No public cutover or family migration is claimed.

Validation after merging `integration/adaptive-theme-presentation` (`Already up to date.`):

- `dart test test/state_presentation_test.dart test/compact_help_presentation_test.dart test/theme_state_help_tracer_test.dart -r compact` — 24 passed.
- `dart format --output=none --set-exit-if-changed .` — 253 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5003 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.

Decisions: markers are display-safe and monochrome, so state never depends on colour; restricted rows remain focusable but are neither selectable nor acceptable; hidden entry keeps Ctrl+T because typed `/help` is answer data, while key capture advertises a route outside the armed gesture. Help failure and unavailable-space outcomes return an unchanged immutable state snapshot rather than mutating a live prompt.

Gaps: all evidence is scripted or synthetic. No real-terminal visual, human screen-reader, native paste, or platform-detection check was performed, and no accessibility qualification is claimed. Family-wide adoption, the public breaking cutover, and human evidence gates remain later tickets.
