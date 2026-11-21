# 17 Block adaptive rust theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Block internally to adaptive Atelier warm-ink light and dark defaults with **rust** as the primary accent, while preserving an uppercase block label establishing hierarchy above indented rows. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = BlockTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = BlockTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
[ CHOOSE FEATURES ]
  > x Starter
    - Library
  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Block defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and rust as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Block text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve an uppercase block label establishing hierarchy above indented rows; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Block's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Block example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Implemented an internal, unexported Block seam (`lib/src/block_theme_presentation.dart`) that composes `ThemeSession`, `resolveColors` and real `TextInput`/`MultiSelect` components. `ThemeSession` now accepts its owning theme's light and dark defaults. The public `BlockTheme` factories and generated matrices remain unchanged until the coordinated cutover in ticket 32.

Palette decisions: the light reference background is Atelier Sepia `#f4eedf` and the dark reference is warm ink `#1b1a18`; rust accents are `#9a4325` light and `#e08b5f` dark. Both palettes leave `background` terminal-native, so only localized highlights may paint a background. Authored normal-text roles are enumerated by `BlockAdaptivePalettes.*TextRoles` and checked at 4.5:1 against their documented reference surface; `border` is chrome and is not part of the normal-text claim.

Validation commands and results, all in this worktree:

- `dart test test/block_theme_adaptive_test.dart` — 13 tests passed.
- `dart test test/block_theme_adaptive_test.dart test/block_theme_factories_test.dart test/block_theme_acceptance_matrix_test.dart` — 106 tests passed.
- `dart test` — 5016 tests passed.
- `dart format --output=none --set-exit-if-changed .` — 0 files changed, exit 0.
- `dart analyze` — no issues found, exit 0.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files, no legacy local tracker, exit 0.
- `python tool/generate_theme_factories.py block`, `python tool/generate_theme_tests.py block`, `python tool/generate_color_themes.py` — exit 0 each; after the generator fixes, regenerating Block sources, Block tests and palettes produced no diff. Regenerating unrelated themes exposed pre-existing drift, which was reverted rather than changed in this ticket.
- `dart run example/block_theme_example.dart` — exit 0; printed adaptive light, adaptive dark and explicit component override renderings.

Evidence limits: every rendering check uses scripted or fake I/O. No real light/dark terminal visual review, native screen-reader session, or human accessibility qualification was performed, so no claim is made about actual terminal contrast, glyph rendering, or reader usability. The component families still emit their current textual state markers (`[focused]`, `[checked]`, `[default]`) rather than the designed Unicode/ASCII glyph pairs, which belong to the later component-migration tickets; this ticket verifies that those markers remain independent, readable, uncoloured and unclipped at 24 columns.
