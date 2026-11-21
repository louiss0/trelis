# 19 Round adaptive plum theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Round internally to adaptive Atelier warm-ink light and dark defaults with **plum** as the primary accent, while preserving a complete enclosure with rounded Unicode corners and contained choices. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = RoundTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = RoundTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
/---------------------\
| Choose features     |
| > x Starter         |
|   - Library         |
\---------------------/
  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Round defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and plum as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Round text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a complete enclosure with rounded Unicode corners and contained choices; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Round's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Round example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the non-exported `lib/src/themes/round_presentation.dart` seam with
authored light (Atelier Sepia warm ink, deep plum accent) and dark (warm
plum-tinted ink, brighter plum accent) defaults. Both keep
`ColorTheme.background` terminal-native and document separate reference
surfaces: light `#F6F1E8`, dark `#1B181D`. The tracer composes each variant's
theme default plus the application replacement and shared/variant roles into
the application layer of the existing `ThemeSession`, then applies component
replacement and shared/variant roles inside the active period. No shared
library or public export was changed, so pre-cutover callers and generated
`RoundTheme` factories remain untouched.

Rendered a real `TextInput` and a real `MultiSelect` through the internal owner
with `PromptStructure.round`, asserting the `?`/`¦`/`?`/`?` enclosure, title,
contained choices, warning status label and compact help outside the bottom
rule in both variants. Tests cover focus/checked/default/restriction markers,
app and component palette layers, `terminalDefault`, indexed degradation,
`NO_COLOR`, a component override that cannot redirect background detection, and
ASCII/no-colour narrow output with rounded ASCII corners (`.`, `'`). No test
claims a fully wrapped 30-column fit: atomic restriction markers stay whole and
may exceed the nominal width, which the narrow test asserts instead.

Validation before integration merge (worktree branch):

- `dart test test/round_adaptive_presentation_test.dart -r compact` — 23 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5026 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `dart run example/round_theme_example.dart` — three scripted renderings completed (light default, dark default, explicit override), exit 0.
- `python tool/generate_color_themes.py`, `python tool/generate_theme_factories.py round`, `python tool/generate_theme_tests.py round`, then `dart format` on the generated Round files — no tracked generated diff. The generator now emits the required `PromptStructure` import and the checked-in spacing; the untracked generated acceptance-matrix file was removed rather than added in this pre-cutover ticket.

Decisions: the authored palettes never set a surface colour, so default
rendering paints no terminal background; the RGB references exist only for the
independent 4.5:1 check (light foreground/muted/accent/success/warning/error/
border 11.64/6.39/8.35/6.33/6.69/7.24/5.94, dark 14.61/7.54/7.59/10.47/
10.33/8.18/4.79). Selection foreground was checked against its plum selection
background (9.06 light, 7.59 dark).

Gaps: all evidence is synthetic or scripted. No real light/dark terminal
review, screen-reader run, native output-capability check, custom/indexed/
transparent-surface contrast check or human accessibility review was performed;
no accessibility qualification is claimed. The public cutover, native detection
and human evidence gates remain later tickets.
