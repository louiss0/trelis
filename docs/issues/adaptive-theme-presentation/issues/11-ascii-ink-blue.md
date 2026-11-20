# 11 Ascii adaptive ink blue theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Ascii internally to adaptive Atelier warm-ink light and dark defaults with **ink blue** as the primary accent, while preserving an ASCII-only question mark, indentation and explicit state symbols. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = AsciiTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = AsciiTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
?  Choose features
   > x Starter
     - Library
   Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Ascii defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and ink blue as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Ascii text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve an ASCII-only question mark, indentation and explicit state symbols; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Ascii's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Ascii example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the internal, non-exported `lib/src/ascii_ink_blue_theme.dart` seam. It
drives real Ascii `TextInput`, `Select` and `MultiSelect` components through
`ThemeSession`, so application palette layers resolve in the active period and
component layers are applied there from the period's already-selected
background. `ThemeSession` gained optional structural default palettes; the
static public `AsciiTheme` factories, prompt signatures and export barrel are
unchanged. `AsciiAdaptivePalettes` is generated from
`tool/ascii_ink_blue_palettes.json` by
`tool/generate_ascii_ink_blue_palettes.py`, including the documented contrast
reference backgrounds.

Decisions: backgrounds stay terminal-native, so no rendered normal text paints
a terminal surface; reference backgrounds are #FAF8F3 for the Atelier Sepia
light direction and #191C26 for warm-ink dark. Ink blue is #1E4E8C light and
#8CB8FF dark. The ASCII `?` heading, two-space indentation and `--` compact
hint spelling remain even under a Unicode-capable output profile. Component
whole palettes still discard the complete effective app palette; variant roles
win over shared roles; component overrides never choose the background or
alter I/O.

Validation on this branch before the integration merge:

- `dart test test/ascii_ink_blue_theme_test.dart -r compact` — 16 passed.
- `dart run example/ascii_adaptive_theme_example.dart` — printed accepted
  answers, the documented light reference, `Light default palette applied:
  true` and `Explicit palette suppressed colour: true`.
- `python tool/generate_ascii_ink_blue_palettes.py --check` — reported current;
  `python tool/generate_color_themes.py` — regenerated 45 palettes with no Git
  diff.
- `dart format --output=none --set-exit-if-changed .` — 257 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5019 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Generator scope: the legacy factory/test generators were exercised for
`ascii` in a temporary copy. Their generated factory test matched the
committed file; the public factory and acceptance-matrix test already differed
from generator output on the integration tip (formatting and case-only drift).
No obsolete palette was reintroduced, and no generated public source or test
was changed here.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal
visual review, native background query, screen-reader check or human
accessibility qualification was performed; contrast ratios do not guarantee an
actual terminal, custom palette, indexed colour or transparent surface. The
shared choice renderer still uses textual state markers (`[focused]`,
`[checked]`, `[default]`); design glyph migration and the public cutover remain
later tickets. At 26 columns the compact help route wraps mid-token, so the
narrow test uses 44 columns to verify it stays intact and unclipped.
