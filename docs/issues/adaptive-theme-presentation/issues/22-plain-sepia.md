# 22 Plain adaptive sepia theme

Status: resolved

**Blocked by:** [09: composable state indicators and compact help](09-state-and-compact-help.md)

**What to build:** Migrate Plain internally to adaptive Atelier warm-ink light and dark defaults with **sepia** as the primary accent, while preserving a bare question with indentation and explicit text symbols, without decoration. Use the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md), and [plan](../../../adaptive-theme-implementation-plan.md) as the contract. Keep the existing public calls buildable and exercise real components through an internal seam before the coordinated public cutover; do not publish or claim a stable new API in this ticket.

## Illustrative usage

**PROPOSED NOT IMPLEMENTED** - future default usage; exact names are not stable:

```dart
final theme = PlainTheme();
final prompt = theme.textInput('Project name');
final result = await prompt.prompt();
```

**PROPOSED NOT IMPLEMENTED** - a component-level palette replaces the effective application palette; `customPalette` is provided by the application:

```dart
final theme = PlainTheme();
final prompt = theme.textInput(
  'Project name',
  colors: ComponentColors.palette(customPalette),
);
final result = await prompt.prompt();
```

A schematic ASCII multi-selection rendering, not a snapshot or final glyph specification (state indicators follow ticket 09):

```text
Choose features
  > x Starter
    - Library
  Space toggle / Enter submit / Ctrl+T help
```

## Acceptance criteria

- [x] Author and test distinct adaptive light- and dark-background Plain defaults using the Atelier warm-ink direction, Atelier Sepia as the light starting point, and sepia as the primary accent; retain coherent semantic success, warning and error roles. Unknown background falls back to dark; explicit background choice wins.
- [x] Render a real Plain text input and a real choice component through the internal seam in both variants; assert their output and palette use, not merely palette object values. Preserve a bare question with indentation and explicit text symbols, without decoration; verify title, content and compact help placement without substituting a generic theme.
- [x] Test palette precedence for both variants: theme default, app whole-palette replacement and shared/variant role overrides, then component whole-palette replacement and shared/variant role overrides. A component whole palette replaces the entire effective app palette; variant roles win over shared roles.
- [x] Test explicit `ColorThemes.terminalDefault` at app and component scope, output capability degradation and non-empty `NO_COLOR` as a hard final restriction, including against explicit colours. Component overrides cannot change background detection or I/O.
- [x] Verify ASCII fallback and no-colour output in real component renderings, with independent focus, selection and default markers, readable status labels and compact help; exercise narrow geometry without clipping essential content or conflating indicators. Preserve Plain's recognizable structure when space permits.
- [x] Preserve the terminal surface by default for both variants; only localized highlights may use background colour. Verify no whole-surface paint in rendered output, including monochrome and narrow cases.
- [x] For each known authored normal-text foreground/reference-background pair in both variants, document the chosen reference background and test a contrast ratio of at least 4.5:1. Do not claim this guarantees contrast on an actual terminal, custom palette, indexed colour or transparent surface.
- [x] Update the relevant generators and generated theme sources/tests together where applicable; test regeneration does not restore obsolete defaults or introduce a partial public cutover. Keep pre-cutover public compatibility and buildability.
- [x] Add or update a Plain example demonstrating adaptive defaults and a separate explicit colour override at the appropriate cutover seam; keep examples aligned with generated sources and avoid treating current example palettes as defaults. Record test commands and results; identify missing real light/dark terminal and human accessibility evidence without claiming qualification.

## Comments

- Implemented the internal `PlainSepiaPalettes`, pure `resolvePlainColors`, and `PlainAdaptivePresentation` seam. Real `TextInput` and `Select` run through the existing `ThemeTextInputTracer` / `ThemeSession` seams; the static `PlainTheme` factories and public export inventory are unchanged.
- Decision: because this is pre-cutover, the adaptive defaults are supplied as the owner's application palette layer with both variants declared. The shared resolver still applies theme-default → app replacement/roles → component replacement/roles, so a component whole palette discards the app layer; no component declaration reaches I/O or background choice. Default palettes keep a terminal-default background; the documented RGB values are contrast references only.
- `dart test test/plain_sepia_adaptive_test.dart`: 19 tests passed (palette authoring, 4.5:1 pairs, both-variant precedence, terminalDefault, capability degradation, `NO_COLOR`, real component output, ASCII/narrow/no-colour, state marker independence).
- `dart format --output=none --set-exit-if-changed .`: 257 files, 0 changed, exit 0. `dart analyze`: No issues found. `dart test`: all tests passed. `dart run tool/check_issue_tracker.dart`: 177 Git-backed tracker files, no legacy local tracker.
- `dart run example/plain_adaptive_example.dart`: printed distinct light/dark default foreground requests, an explicit override request and the scripted answer. The pre-existing `plain_theme_example.dart` now states that its named palettes are examples, not defaults.
- Regeneration check: running both shared generators for all 14 non-plain themes changed generated theme sources/tests and created three previously absent acceptance-matrix tests on the integration tip. That drift is pre-existing and unrelated to Plain; it was reverted with `git checkout -- lib/src/themes test` and generator-owned files are untouched by this ticket. No obsolete defaults or partial public cutover were introduced.
- Honest gaps: evidence is scripted/synthetic only. No real light/dark terminal visual review, native terminal check, screen-reader or human accessibility qualification was performed, and no release gate is claimed. `Select` still emits its existing textual state markers rather than the ticket-09 Unicode/ASCII glyph vocabulary; the independent glyph pairs were verified at the state-presentation seam and real marker independence was verified in component output, with the component glyph migration left to its owning ticket.
