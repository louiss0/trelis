# 03 Resolve interaction deterministically

Status: ready-for-agent

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
- [ ] Table-driven injected tests cover auto/on/off, rich/linear/auto and positive, negative and unknown app/native hints; either eligible positive can enable automatic linear screen-reader presentation, negatives do not veto positives.
- [ ] Explicit off defeats hints but permits independently requested linear; explicit rich defeats automatic detection. Explicit on plus rich reports conflict; no runnable state allows screen-reader active with rich.
- [ ] Explicit rich stays requested even when unsupported; integration availability remains separate and unavailable is not a conflict. Failed/unknown observations do not block resolution.
- [ ] Preserve current public API and prototype evidence while replacing incompatible expectations; record tests and results. Do not claim native or human screen-reader qualification from synthetic tests.
