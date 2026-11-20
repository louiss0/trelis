# 14 Colon adaptive ink blue theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Colon internally to adaptive Atelier warm-ink light and dark defaults with **ink blue** as the primary accent, while preserving machine-like field names, colon separators and explicit hint prefixes. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = ColonTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = ColonTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
features: Choose features
  > x Starter
    - Library
hint: Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Colon defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and ink blue as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Colon text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve machine-like field names, colon separators and explicit hint prefixes; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Colon's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Colon example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the internal, non-exported `lib/src/themes/colon_theme_internal.dart` seam. It pairs authored light and dark Colon defaults with `ThemeSession`, `resolveColors` and `PromptStructure.colon`, and drives real `TextInput`, `Select` and `MultiSelect` components. The light reference is Atelier Sepia (`#f4f1ea`) and the dark reference is warm ink (`#1c1e24`); ink blue is the primary accent in both variants, with coherent success, warning and error roles. Both authored palettes request the terminal's default background. `ThemeSession` now accepts structural light/dark defaults while keeping terminal-default behaviour for existing owners. The typed diagnostic grammar (`ask:`, `hint:`, `state:`, `warning:`, `result:` and the `  :: ` editable marker) is preserved in both variants and in ASCII/no-colour output.

Validation after merging `integration/adaptive-theme-presentation` (`Already up to date.`):

- `dart test test/colon_theme_adaptive_test.dart test/colon_theme_factories_test.dart test/colon_theme_acceptance_matrix_test.dart -r compact` — 108 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed (exit 0).
- `dart analyze` — no issues found (exit 0).
- `dart test -r compact` — 5018 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `python tool/generate_theme_factories.py colon`, `python tool/generate_theme_tests.py colon`, followed by `git diff --exit-code` — regeneration diff exit 0. The generators now format their output, so regeneration neither restores obsolete defaults nor introduces a partial public cutover.
- `dart run example/colon_theme_example.dart` — exit 0; both adaptive defaults and separate application/component palette replacements run through the internal seam.

Decisions: component overrides are layered inside the period from the already-resolved background, so they cannot change detection or I/O. A component whole-palette replacement discards the effective app palette including its role overrides; variant roles win over shared roles at both scopes. Explicit `ColorThemes.terminalDefault`, indexed/none colour depth and non-empty `NO_COLOR` remain final restrictions. The pre-cutover static `ColonTheme` factories and explicit named palettes still build and render unchanged. Marker independence is verified with the current component vocabulary (`[focused]`, `[checked]`/`[unchecked]`, `[default]`, `[unavailable: reason]`); adopting ticket 09's symbol primitives in component families remains later work. At ten columns the atomic textual markers stay whole and distinct instead of being clipped, which can make an individual marker line wider than the column count.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal review, native background query, screen-reader, human accessibility or platform-specific contrast check was performed, and no qualification is claimed. The illustrative public `ColonTheme()` instance API remains unimplemented until the coordinated cutover.
