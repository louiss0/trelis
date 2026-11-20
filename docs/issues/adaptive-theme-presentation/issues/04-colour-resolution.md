# 04 Resolve colour preferences and overrides

Status: ready-for-agent

**Blocked by:** None

**What to build:** Add internal immutable separate theme colour preferences and component overrides, with deterministic resolution from injected output facts. Theme preferences compose overrides with background and query controls; component overrides cannot change detection or I/O. Keep current public API buildable; do not perform native terminal queries here. See the [design](../../../adaptive-theme-accessibility-design.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(colors: ColorPreferences(background: Background.auto));
final prompt = theme.textInput('Name', colors: ComponentColors.palette(palette));
```

## Acceptance criteria
- [ ] Test light, dark and unknown-to-dark fallback, explicit choice over injected query over passive hint, selected output depth degradation and explicit terminal-native palettes.
- [ ] Test theme default → app replacement → app shared/variant roles → component replacement → component shared/variant roles. Variant roles win shared roles; a component replacement discards the entire effective app palette, including its roles; omission inherits.
- [ ] Non-empty `NO_COLOR` wins over every explicit override at the final output boundary; test empty `NO_COLOR`, no colour capability and no palette supplied separately.
- [ ] Test malformed/unavailable injected detection facts fall back safely without real native calls; record commands and results. Adaptive authored palettes and real-terminal visual qualification are not implied by this resolver.
