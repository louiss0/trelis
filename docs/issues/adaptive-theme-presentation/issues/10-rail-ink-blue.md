# 10 Rail adaptive ink blue theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Rail internally to adaptive Atelier warm-ink light and dark defaults with **ink blue** as the primary accent, while preserving a continuous vertical rail linking the question, choices and help. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = RailTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = RailTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
+  Choose features
|  > x Starter
|    - Library
+  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Rail defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and ink blue as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Rail text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a continuous vertical rail linking the question, choices and help; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Rail's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Rail example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the internal, non-exported `lib/src/rail_ink_blue_theme.dart` seam. It
drives real Rail `TextInput` and `Select` components through `ThemeSession`,
so application palette layers resolve inside the active period and component
layers are applied there from the period's already-selected background.
`ThemeSession` gained optional structural default palettes; the static public
`RailTheme` factories, prompt signatures and export barrel are unchanged.
`RailAdaptivePalettes` is generated from `tool/rail_ink_blue_palettes.json`
by `tool/generate_rail_ink_blue_palettes.py`, including the documented
contrast reference backgrounds.

Decisions: palette backgrounds stay terminal-native, so no rendered normal
text paints a terminal surface; reference backgrounds are #FAF8F3 for the
Atelier Sepia light direction and #191C26 for warm-ink dark. Ink blue is
#1E4E8C light and #8CB8FF dark. A component whole palette still discards the
complete effective app palette; variant roles win shared roles; component
overrides never choose the background or alter I/O.

Validation after merging `integration/adaptive-theme-presentation` (merge
reported `Already up to date.`):

- `dart test test/rail_ink_blue_theme_test.dart -r compact` — 13 passed.
- `dart run example/rail_adaptive_theme_example.dart` — printed accepted
  answers, the documented light reference, `Light default palette applied:
  true` and `Explicit palette suppressed colour: true`.
- `python tool/generate_color_themes.py` — 45 palettes regenerated with no
  Git diff; `python tool/generate_rail_ink_blue_palettes.py --check` —
  reported current.
- `dart format --output=none --set-exit-if-changed .` — 257 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5016 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files;
  no legacy local tracker remains.

Generator scope: the legacy `tool/generate_theme_factories.py rail` was
checked in a temporary directory and was already stale relative to the
committed public factories before this ticket; no generated public factory or
barrel export was changed here.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal
visual review, native background query, screen-reader check or human
accessibility qualification was performed, and contrast ratios do not
guarantee an actual terminal, custom palette, indexed colour or transparent
surface. The existing choice renderer still uses textual state markers;
Unicode glyph migration and the public cutover are later tickets. A very long
restriction reason in a 26-column terminal can exceed the atomic marker width;
the narrow test keeps the reason short and verifies no clipping of essential
content or help.
