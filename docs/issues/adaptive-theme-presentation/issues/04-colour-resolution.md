# 04 Resolve colour preferences and overrides

Status: resolved

**Blocked by:** None

**What to build:** Add internal immutable separate theme colour preferences and component overrides, with deterministic resolution from injected output facts. Theme preferences compose overrides with background and query controls; component overrides cannot change detection or I/O. Keep current public API buildable; do not perform native terminal queries here. See the [design](../../../adaptive-theme-accessibility-design.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(colors: ColorPreferences(background: Background.auto));
final prompt = theme.textInput('Name', colors: ComponentColors.palette(palette));
```

## Acceptance criteria
- [x] Test light, dark and unknown-to-dark fallback, explicit choice over injected query over passive hint, selected output depth degradation and explicit terminal-native palettes.
- [x] Test theme default → app replacement → app shared/variant roles → component replacement → component shared/variant roles. Variant roles win shared roles; a component replacement discards the entire effective app palette, including its roles; omission inherits.
- [x] Non-empty `NO_COLOR` wins over every explicit override at the final output boundary; test empty `NO_COLOR`, no colour capability and no palette supplied separately.
- [x] Test malformed/unavailable injected detection facts fall back safely without real native calls; record commands and results. Adaptive authored palettes and real-terminal visual qualification are not implied by this resolver.

## Comments

Implemented the internal `lib/src/color_resolution.dart` seam: immutable
`ColorPreferences` (background, query control, app replacement and roles),
`ComponentColors` overrides and a pure `resolveColors` driven only by injected
`ColorDetectionFacts`. The public barrel and generated files are unchanged.

Key decision: a component whole-palette replacement discards the complete
effective app palette, including app role overrides; component roles then layer
on the replacement. Variant roles win shared roles inside each scope, and
omission inherits. `NO_COLOR` is applied only at the final output boundary, so
the resolved palette remains inspectable while styling is suppressed.
`shouldQueryBackground` reports resolver-level eligibility only.

Validation after merging the integration branch (merge reported
`Already up to date.`):

- `dart test test/color_resolution_test.dart` — 14 passed.
- `dart test test/color_resolution_test.dart test/color_themes_test.dart test/plain_theme_color_application_test.dart test/text_input_colour_rendering_test.dart test/theme_palette_matrix_test.dart` — 95 passed.
- `dart test` — 4821 passed.
- `dart format --output=none --set-exit-if-changed .` — 222 files, 0 changed.
- `dart analyze lib test/color_resolution_test.dart` and `dart analyze` — no issues.

Gaps: no adaptive palette authoring, native background query, active-period
caching, or real-terminal visual qualification is claimed here. Detection facts
are injected; no native or real-terminal call is made, and no human
accessibility evidence is implied.
