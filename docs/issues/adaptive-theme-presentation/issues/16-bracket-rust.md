# 16 Bracket adaptive rust theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Bracket internally to adaptive Atelier warm-ink light and dark defaults with **rust** as the primary accent, while preserving a short bracketed title band above compact indented answers. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = BracketTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = BracketTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
[ Choose features ]
  > x Starter
    - Library
  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Bracket defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and rust as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Bracket text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a short bracketed title band above compact indented answers; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Bracket's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Bracket example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added an internal, non-exported `lib/src/themes/bracket_theme_internal.dart` seam:
`BracketPaletteDefaults` authors distinct Atelier-warm-ink light and dark
palettes (Atelier Sepia reference `(250,244,232)`, warm-ink reference
`(30,27,25)`) with rust accents `(166,69,38)` and `(232,135,90)`, and a
terminal-native background role so no surface is painted. `BracketInternalPresentation`
feeds those defaults into the merged `ThemeSession` and `resolveColors` seams and
renders real `TextInput`, `Select` and `MultiSelect` components with
`PromptStructure.bracket`. `ThemeSession` gained optional light/dark default
arguments, defaulting to terminal-native so existing public calls are unchanged.

Decisions: component overrides layer on the period-resolved palette through the
existing resolver, so a component whole palette discards app overrides and
variant roles win over shared roles while background and I/O stay theme-owned.
Bracket's own grammar has no `warning:`/`state:`/`result:` prefixes; validation
and linear output stay readable plain text, and the shared
`state_help_presentation.dart` `renderStatus` seam supplies the explicit typed
status label. Regeneration of the palette/factory/factory-test generators was
exercised: it produced only pre-existing formatting/import drift in generated
files (no adaptive defaults and no public cutover), and those generated files
were restored. Public `BracketTheme` factories still default to
`ColorThemes.terminalDefault`; the new example uses the internal seam for
adaptive defaults and a separate public explicit override.

Validation (before integration merge):

- `dart test test/bracket_theme_adaptive_test.dart -r compact` — 17 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5020 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `dart run example/bracket_theme_example.dart` — exit 0.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal,
native screen-reader, human accessibility, or platform-detection check was
performed; a passing 4.5:1 reference calculation does not guarantee contrast on
an actual terminal, custom palette, indexed colour or transparent surface. The
public breaking cutover and human evidence gates remain later tickets.
