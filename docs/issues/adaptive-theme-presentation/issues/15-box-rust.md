# 15 Box adaptive rust theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Box internally to adaptive Atelier warm-ink light and dark defaults with **rust** as the primary accent, while preserving a square ruled enclosure containing its title, rows and help. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = BoxTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = BoxTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
+---------------------+
| Choose features     |
| > x Starter         |
|   - Library         |
+---------------------+
  Space toggle / Enter submit / Ctrl+T help
```

## Comments

Implemented behind internal seams only. The public `BoxTheme` factories still default to `ColorThemes.terminalDefault` until the coordinated cutover (ticket 32).

- Authored `StructuralThemePalettes.box`: Atelier warm-ink light from the Atelier Sepia direction, warm-ink dark, rust as the primary accent, with coherent success/warning/error roles. Both variants keep the background role terminal-native; `BoxPaletteReference` declares the reference surfaces used for contrast checks. Unknown background falls back to dark and explicit choice wins through the existing resolver.
- Added internal `ThemePaletteDefaults`, threaded through `ThemeSession`, and extended `ThemeTextInputTracer` plus a new internal `ThemeChoiceTracer` with a fixed structure and the theme's defaults. No public export-barrel change.
- `test/box_theme_adaptive_test.dart` renders a real Box text input and a real `MultiSelect` in light, dark, ASCII/no-colour and narrow profiles. It asserts rust role SGRs, the square enclosure, the compact hint below the bottom rule, independent focus/default/checked/unchecked markers, a readable unavailable reason, and no whole-surface paint. `test/box_theme_adaptive_palette_test.dart` covers precedence for both variants, fallback/query/explicit background choice, `terminalDefault` at both scopes, `NO_COLOR`, depth degradation, component overrides unable to change background or I/O, authored 4.5:1 pairs and the regeneration/public-cutover guard.
- Generators: ran `python tool/generate_color_themes.py` (45 palettes; generated file unchanged) and all 14 `generate_theme_factories.py` / `generate_theme_tests.py` invocations. The latter rewrote pre-existing hand-formatting drift in unrelated generated files; those edits were reverted and are not part of this branch. The guard test checks regenerated sources still default to terminal-native colours.
- `example/box_theme_example.dart` shows the internal adaptive seam and a separate explicit public override; running it reports terminal-native public omission.
- Validation: `dart format --output=none --set-exit-if-changed .` (258 files, 0 changed); `dart analyze` (no issues); `dart test` (5044 passed); `dart run tool/check_issue_tracker.dart` (177 Git-backed tracker files, no legacy tracker).

Honest gaps: scripted output does not establish real light/dark terminal appearance, native screen-reader behavior or human accessibility qualification. The real choice component still emits ticket-09 textual markers (`[focused]`, `[default]`, `[checked]`, `[unchecked]`); the Unicode/ASCII glyph pairs are verified only at the internal state-primitives seam until ticket 26 migrates choices. Narrow evidence uses 40 columns; a longer unavailable reason at 24 columns can overflow the shared choice row, which is not fixed here. Contrast claims apply only to the declared reference surfaces, not actual, custom, indexed or transparent backgrounds.

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Box defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and rust as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Box text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a square ruled enclosure containing its title and rows, with the compact help below the active content; verify placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Box's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Box example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.
