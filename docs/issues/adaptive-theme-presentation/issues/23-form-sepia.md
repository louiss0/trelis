# 23 Form adaptive sepia theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Form internally to adaptive Atelier warm-ink light and dark defaults with **sepia** as the primary accent, while preserving uppercase field labels, a rule and a left edge forming a field-oriented layout. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = FormTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = FormTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
FEATURES
---------------
| > x Starter
|   - Library
| Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Form defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and sepia as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Form text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve uppercase field labels, a rule and a left edge forming a field-oriented layout; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Form's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Form example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

Added the non-exported `lib/src/themes/form_presentation.dart` seam with
authored light (Atelier Sepia warm ink, deep sepia accent) and dark (warm
sepia-tinted ink, brighter sepia accent) defaults. Both keep
`ColorTheme.background` terminal-native and document separate reference
surfaces: light `#F3ECDD`, dark `#221D19`. The tracer composes each variant's
theme default plus application replacement and shared/variant roles into the
application layer of the existing `ThemeSession`, then applies component
replacement and shared/variant roles inside the active period. No public export
or generated public factory signature changed; pre-cutover callers keep their
terminal-native factories.

Rendered a real `TextInput` and `MultiSelect` through the internal owner with
`PromptStructure.form`, asserting the uppercase field label, measured rule,
left edge, styled foreground/accent/border/muted roles and the compact hint in
both variants. The screen-reader slice exposed a gap in the first seam version:
essential text before the prompt was missing, so the tracer now writes it
through the owned session before the component renders. Palette assertions
cover theme defaults, app and component whole palettes, shared/variant roles,
explicit `terminalDefault`, indexed degradation, hard `NO_COLOR`, and a
component override that cannot redirect background detection. ASCII no-colour
narrow renderings keep independent focused/checked/default markers, a readable
status label and the help route; wrapping splits phrases but does not clip or
conflate markers. No rendering paints the terminal surface, including
monochrome and narrow cases.

Validation on the worktree branch before integration merge:

- `dart test test/form_theme_adaptive_presentation_test.dart -r compact` — 29 passed.
- `dart format --output=none --set-exit-if-changed .` — 256 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5032 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.
- `dart run example/form_theme_example.dart` — three scripted renderings (light default, dark default, explicit override), exit 0.
- `python tool/generate_theme_factories.py form`, then `dart format` on the generated source — no tracked generated diff. The factory generator now emits the required `PromptStructure` import so regenerated `FormTheme` source compiles.
- `python tool/generate_theme_tests.py form` — regenerated acceptance matrix reintroduced case-sensitive label assertions that fail against Form's uppercase heading (12 failures), so that generated test was restored and the shared test generator left unchanged; factory regeneration and generated source remain clean.

Decisions: the authored palettes never request a surface colour, so default
rendering paints no terminal background; the RGB references exist only for the
independent 4.5:1 check (light foreground/muted/accent/success/warning/error/
border 12.39/6.98/5.86/7.16/6.40/7.12/6.15, dark 13.87/7.30/7.48/9.02/8.94/
7.20/5.10). Selection foreground was checked against its sepia selection
background (8.14 light, 7.65 dark).

Gaps: all evidence is synthetic or scripted. No real light/dark terminal
review, screen-reader run, native output-capability check, custom/indexed/
transparent-surface contrast check or human accessibility review was performed;
no accessibility qualification is claimed. The shared acceptance-test
generator still needs a case-insensitive expectation rule for uppercase themes.
The public cutover, native detection and human evidence gates remain later
tickets.
