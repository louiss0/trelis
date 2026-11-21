# 24 Ledger adaptive sepia theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Ledger internally to adaptive Atelier warm-ink light and dark defaults with **sepia** as the primary accent, while preserving a numbered step, dotted rule and indented answers suggesting an auditable sequence. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = LedgerTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = LedgerTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
1. Choose features
..................
   > x Starter
     - Library
   Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Ledger defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and sepia as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Ledger text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a numbered step, dotted rule and indented answers suggesting an auditable sequence; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Ledger's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Ledger example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Authored Ledger's adaptive defaults in a new internal, non-exported
`lib/src/ledger_adaptive_theme.dart`. Light starts from the Atelier Sepia paper
direction (reference background `#f7f0e2`) and dark from a deep warm ink
(reference background `#211d19`); sepia is the primary accent in both. Both
palettes leave the `background` role at the terminal default, so the terminal
surface is never painted; only the selection roles carry a localized highlight.
`ThemeSession` gained optional `lightDefault`/`darkDefault` constructor inputs
defaulting to terminal-native colours, so existing callers and the public
static `LedgerTheme` factories are unchanged before cutover 32.

Real `TextInput` and `Select` components are rendered with
`PromptStructure.ledger` through the theme-owned session in both variants.
Assertions cover the numbered `01 /` heading, dotted rule, indented body and
`note:` compact hint, plus the palette's foreground SGR in the output and the
absence of any background paint. Palette precedence, `terminalDefault`,
`NO_COLOR`, depth degradation, ASCII/narrow rendering and component-scope
background immunity are covered by the focused suite. State glyph vocabulary
and hint placement are checked with the ticket 09 primitives; the real Select
still emits its legacy textual `[focused]`/`[default]` markers, and full glyph
adoption in component renderers remains ticket 26.

Validation (commands and results):

- `dart test test/ledger_adaptive_theme_test.dart -r compact` — 19 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed.
- `dart analyze` — No issues found.
- `dart test -r compact` — 5021 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `dart run example/ledger_theme_example.dart` — dark fallback and light hint both select the authored sepia accent; explicit override applied.
- Regeneration with `python tool/generate_theme_factories.py ledger`,
  `python tool/generate_theme_tests.py ledger` and
  `python tool/generate_color_themes.py`, followed by `dart format`: no
  obsolete default or public API was restored in the generated Ledger factory,
  Ledger acceptance tests or palette source. Raw generator output drops a
  required `prompt_structure.dart` import from the Ledger factory — a
  pre-existing generator/template drift unrelated to this ticket — so the
  committed generated file was restored rather than widening scope.

Decisions: the authored pairs are design references only, with a measured
minimum contrast of about 5.2:1 in light and 7.5:1 in dark for the six normal
text roles; this does not guarantee contrast on a real terminal, a custom or
indexed palette, or a transparent surface. Component overrides cannot change
background detection or I/O because those remain theme-owned.

Gaps: all evidence is scripted or synthetic. No real light/dark terminal
visual review, native background query, screen-reader session or human
accessibility check was performed, and no accessibility qualification is
claimed. The adaptive defaults remain internal until the coordinated public
cutover; the human evidence gates remain separate tickets.
