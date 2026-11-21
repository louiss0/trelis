# 26 Migrate boolean and basic choice prompts

Status: resolved

**Blocked by:** [09](09-state-and-compact-help.md)

**What to build:** Migrate Confirm, Checkbox, Toggle, Select, Radio and MultiSelect using the internal theme/session and shared state/help seams, without prematurely publishing the prototype or breaking existing calls. The [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md) govern behavior.

## Proposed examples — NOT IMPLEMENTED

```dart
final confirmation = RailTheme().confirm('Continue?');
final answer = await confirmation.prompt();
```

```dart
final choices = RailTheme().multiSelect('Features', options); // List<Choice<T>>
final first = await choices.prompt();
final again = await choices.prompt(); // Configured initial selection, not first.
```

## Acceptance criteria

- [x] Cover each named component with real component tests in rich, normal linear and screen-reader presentation; preserve boolean, choice and result types and selection semantics.
- [x] Test focus, selected/checked, unchecked and default as independent states, including all five theme-wide single-selection styles; default does not imply selection. Verify ASCII pairs and meaningful `NO_COLOR` output.
- [x] Keep locked `[L]` and unavailable `[!]` choices focusable but not selectable or acceptable, with readable reasons in rich and linear output; preserve validation and navigation safety.
- [x] Always show compact primary-action/help guidance despite hidden instructions, at rich bottom or after normal linear content; put screen-reader essential guidance before the prompt. Detailed help preserves selection, focus and any draft/caret.
- [x] Route components and internal delegates through theme-owned session, interaction and colors; never treat a delegate as a second external prompt or add invocation-level I/O.
- [x] Test acceptance, validation failure/retry, cancel, interrupt, unavailable and `InputEnded`, and sequential reuse from configured initial values; reject concurrent prompt invocations.
- [x] Verify narrow layouts, Unicode and ASCII, no-color rendering and control behavior independently for each affected family, including safe help and any editable or pasted input.
- [x] Record automated regression commands/results and any missing human screen-reader or native visual evidence; scripted tests alone do not qualify accessibility.

## Comments

Added the internal, non-exported `lib/src/theme_choice_components.dart` seam:
`ThemeBooleanPrompt` (confirm/checkbox/toggle), `ThemeSingleChoicePrompt<T>`
(select/radio) and `ThemeMultiSelectPrompt<T>`. Each instance captures immutable
configuration, owns one `ThemeSession`, resolves mode and component colours in
that period, emits screen-reader essential guidance before the real component,
and delegates with the session handle. No public constructor, static factory,
prompt signature or export was changed.

Choice rows now accept a theme-wide `ChoicePresentationConfig` from the shared
state/help primitives. The real components render focus, selection, checked,
default and restriction positions independently through that vocabulary; the
legacy textual markers remain the default until the coordinated cutover. A
locked or unavailable option keeps a focusable delegated `Choice` with a plain
readable reason, while the configuration carries the `[L]` / `[!]` category.
The themed MultiSelect also separates its configured default marker from its
initial checked values.

Validation after `git merge --no-edit integration/adaptive-theme-presentation`
(reported `Already up to date.`):

- `dart test test/theme_choice_components_test.dart -r compact` — 19 passed.
- Focused regression set (`boolean`, `select_radio`, `multi_select`,
  `component_acceptance_matrix`, `state_presentation`, new themed choice suite)
  — 214 passed.
- `dart format --output=none --set-exit-if-changed .` — 255 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5022 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Decisions: linear hints now name `/help opens help.` explicitly so hidden
instructions still advertise the mandatory help route; rich and linear modal
help remain with the real components, which restore focus and draft on
dismissal. Restriction prose stays plain text beside a categorical marker so it
is not duplicated by the component's own `Unavailable:` status. The local
mode/colour helpers avoid depending on ticket 25's unpublished session helpers;
that duplication can be collapsed at the coordinated cutover.

Gaps: all evidence is scripted or synthetic. No real terminal, native screen
reader, human accessibility, real light/dark visual or platform-detection check
was performed, and no accessibility qualification is claimed. The public API
cutover, examples and human evidence gates remain later tickets.
