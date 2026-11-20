# 13 Chevron adaptive ink blue theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Chevron internally to adaptive Atelier warm-ink light and dark defaults with **ink blue** as the primary accent, while preserving a leading chevron question and a directional help hint without a full frame. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = ChevronTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = ChevronTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
> Choose features
  > x Starter
    - Library
  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Chevron defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and ink blue as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Chevron text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a leading chevron question and a directional help hint without a full frame; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Chevron's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Chevron example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the internal, non-exported `lib/src/themes/chevron_theme_internal.dart` seam. It pairs authored light and dark Chevron defaults with `ThemeSession`, `resolveColors` and `PromptStructure.chevron`, and drives real `TextInput`, `Select` and `MultiSelect` components. The light reference is Atelier Sepia (`#f4f1ea`) and the dark reference is a warm ink (`#1c1e24`); ink blue is the primary accent in both variants, with coherent success, warning and error roles. Both palettes request the terminal's default background. `ThemeSession` now accepts structural light/dark defaults, retaining terminal-default behaviour for existing owners.

Validation before the integration merge:

- `dart test test/chevron_theme_adaptive_test.dart test/chevron_theme_factories_test.dart test/chevron_theme_acceptance_matrix_test.dart -r compact` — 106 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed (exit 0).
- `dart analyze` — no issues found (exit 0).
- `dart test -r compact` — 5017 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `python tool/generate_theme_factories.py chevron`, `python tool/generate_theme_tests.py chevron`, `python tool/generate_color_themes.py`, followed by `git diff --exit-code -- lib/src/themes/chevron_theme.dart test/chevron_theme_factories_test.dart test/chevron_theme_acceptance_matrix_test.dart lib/src/color_theme_palettes.g.dart` — regeneration diff exit 0. The generators format their output, so regeneration does not restore obsolete defaults or add a public cutover.
- `dart run example/chevron_theme_example.dart` — exit 0; both adaptive variants and separate application/component palette replacements run through the internal seam.

Decisions: component overrides are layered inside the period from the already-resolved background, so they cannot change detection or I/O. A component whole-palette replacement discards the effective app palette including its role overrides; variant roles win over shared roles at both scopes. Explicit `ColorThemes.terminalDefault`, indexed/none depth and non-empty `NO_COLOR` stay final restrictions. The pre-cutover static `ChevronTheme` factories and explicit named palettes still build and render unchanged. Marker independence and readable validation text are verified against the current component vocabulary (`[focused]`, `[checked]`/`[unchecked]`, `[default]`, `[unavailable: reason]`); adopting ticket 09's symbol primitives in component families remains later work.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal review, native background query, screen-reader, human accessibility or platform-specific contrast check was performed, and no qualification is claimed. The illustrative public `ChevronTheme()` instance API remains unimplemented until the coordinated cutover.
