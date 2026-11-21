# 18 Branch adaptive plum theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Branch internally to adaptive Atelier warm-ink light and dark defaults with **plum** as the primary accent, while preserving a title that branches into a continuing vertical context line for choices. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = BranchTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = BranchTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
Choose features
|
+-- > x Starter
+--   - Library
`-- Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Branch defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and plum as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Branch text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a title that branches into a continuing vertical context line for choices; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Branch's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Branch example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the non-exported `lib/src/themes/branch_presentation.dart` seam with authored light (Atelier Sepia warm ink, deep plum accent) and dark (warm plum-tinted ink, bright plum accent) defaults. Both keep `ColorTheme.background` terminal-native and expose separate documented reference surfaces: light `#F6F1E8`, dark `#1B181D`. `ThemeSession` now accepts theme defaults instead of hardcoding `ColorThemes.terminalDefault`; the text and choice tracers share one component-colour application helper, so the reviewed app/component scope order is applied in real component output.

Rendered `TextInput`, `Select` and `MultiSelect` through the internal owner with `PromptStructure.branch`, asserting the `├`/`│`/`└` and `+-`/`|`/`\-` spines, title/body/hint order, focus/checked/default/restriction markers, palettes, `terminalDefault`, `NO_COLOR`, ASCII/narrow degradation and the absence of whole-surface paint. Added `example/branch_theme_example.dart` for both adaptive defaults and a separate explicit whole-palette override; it uses the internal seam and is labelled unstable. Public `BranchTheme` factories, exports and compatibility inventory were not changed.

Validation before integration merge (worktree branch):

- `dart test test/branch_adaptive_presentation_test.dart -r compact` — 21 passed.
- `dart format --output=none --set-exit-if-changed .` — 258 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5024 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `dart run example/branch_theme_example.dart` — three scripted renderings completed (light default, dark default, explicit override).
- `python tool/generate_color_themes.py`, `python tool/generate_theme_factories.py branch`, `python tool/generate_theme_tests.py branch`, then `dart format` on the generated Branch files — no generated diff. The generator now emits the required `PromptStructure` import and the checked-in spacing. An exploratory all-theme regeneration was reverted: unrelated themes already drift from their generators, and fixing them is outside this ticket.

Decisions: the authored palettes do not set a surface colour, so default rendering never paints the terminal; the reference RGB values exist only for the independent 4.5:1 checks (light foreground/muted/accent/success/warning/error/border 11.9/6.52/7.82/6.05/6.5/6.74/5.58, dark 14.54/7.41/7.67/10.47/10.33/8.18/4.66). Selection foreground was checked against its plum selection background (8.54 light, 7.67 dark). Narrow ASCII output wraps atomic restriction markers without truncating them; it can exceed the nominal 30-cell width, so the test asserts no clipping rather than claiming a perfect fit.

Gaps: all evidence is synthetic or scripted. No real light/dark terminal review, screen-reader run, native output-capability check, custom/indexed/transparent-surface contrast check or human accessibility review was performed; no accessibility qualification is claimed. The public cutover, native detection and human evidence gates remain later tickets.
