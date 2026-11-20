# 03 Resolve interaction deterministically

Status: resolved

**Blocked by:** None

**What to build:** Introduce internal immutable interaction preferences and an injectable deterministic resolver. A successful value contains rich/linear mode and a screen-reader flag; keep transitions private and distinguish conflicts from unavailable outcomes. No native detection or public cutover in this ticket. See the [design](../../../adaptive-theme-accessibility-design.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final preferences = InteractionPreferences(
  mode: PromptMode.auto,
  screenReader: ScreenReaderPreference.on,
);
final result = resolveInteraction(preferences, facts);
```

## Acceptance criteria
- [x] Table-driven injected tests cover auto/on/off, rich/linear/auto and positive, negative and unknown app/native hints; either eligible positive can enable automatic linear screen-reader presentation, negatives do not veto positives.
- [x] Explicit off defeats hints but permits independently requested linear; explicit rich defeats automatic detection. Explicit on plus rich reports conflict; no runnable state allows screen-reader active with rich.
- [x] Explicit rich stays requested even when unsupported; integration availability remains separate and unavailable is not a conflict. Failed/unknown observations do not block resolution.
- [x] Preserve current public API and prototype evidence while replacing incompatible expectations; record tests and results. Do not claim native or human screen-reader qualification from synthetic tests.

## Comments

Implemented the internal seam in `lib/src/interaction_resolution.dart`; it is
not exported from `lib/trelis.dart`. `InteractionPreferences` holds immutable
mode, screen-reader preference and positive-only application hint.
`InteractionFacts` carries injected output capability, native observation,
locality, interactivity and integration preflight availability. The private
resolver returns a `ResolvedInteraction` (rich/linear plus screen-reader flag,
rejecting screen-reader with rich), `InteractionConflict` or
`InteractionUnavailable`. Explicit rich stays requested on unsupported output;
only integration preflight produces unavailable. Native positives require a
local, interactive session; negative, failed and unknown observations never
veto an affirmative hint. Conflict is checked before preflight unavailability.
No native API, terminal query, generated file or public signature changed.

Validation on this branch:

- `dart pub get` - resolved dependencies for analysis and tests.
- `dart test test/interaction_resolution_test.dart -r compact` - 28 tests passed.
- `dart test -r compact` - 4835 tests passed.
- `dart format --output=none --set-exit-if-changed .` - 222 files, 0 changed.
- `dart analyze` - No issues found.
- `dart run tool/check_issue_tracker.dart` - 177 tracker files, no legacy local tracker.

Gaps: this synthetic resolver does not detect screen readers or establish
locality, wire theme-owned active periods/callbacks, change component output,
or provide native or human screen-reader qualification. Native observations,
active-period caching and platform evidence remain later tickets and gates.
