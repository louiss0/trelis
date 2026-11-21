# 28 Migrate formatted value prompts

Status: resolved

**Blocked by:** [25](25-text-secret-multiline.md)

**What to build:** Migrate Slider, RangeSlider, NumberInput, PortInput, DurationInput, DateInput, TimeInput, TimezoneSelect, CronInput, MaskedInput, ColorInput and TagInput. Use theme-owned internal presentation and session seams, preserving public calls until the coordinated cutover. Follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Proposed examples — NOT IMPLEMENTED

```dart
final quantity = RailTheme().numberInput('Quantity');
final value = await quantity.prompt();
```

```dart
final date = RailTheme().dateInput('Date');
final first = await date.prompt();
final next = await date.prompt(); // Restarts from the configured initial date.
```

## Acceptance criteria

- [x] Exercise every listed real component in rich, linear and screen-reader modes, preserving typed values, formatting, validation, ranges, defaults and domain-specific operations.
- [x] Communicate focus, current value, validation, selection and status without color; cover Unicode, ASCII, `NO_COLOR` and narrow layouts, including textual screen-reader states.
- [x] Show mandatory compact primary-action/help hints at rich bottom and after normal linear content, and essential screen-reader instructions before each prompt despite hidden instructions; detailed help preserves draft, focus and caret.
- [x] Independently verify editing and paste safety for applicable fields: escaped or identified pasted command-shaped values survive invalid retries, help/cancel work despite short value limits, and recognized multiline paste is rejected in single-line fields without losing draft; capability-check and clean up paste reporting.
- [x] Test representative range bounds, numeric/port validation, temporal and timezone handling, cron parsing/preview, masks, color values and tag editing without changing existing domain semantics or exposing unsafe content.
- [x] Route composite/delegated editors through the theme owner without registering a second external prompt; respect resolved interaction and component color overrides rather than adding per-prompt session configuration.
- [x] Test acceptance, validation failure/retry, cancellation, interruption, unavailable and `InputEnded`; sequential reuse returns to configured initial values, and concurrent prompt use is rejected.
- [x] Add automated family and session regressions, record commands/results and unperformed native-terminal or human screen-reader checks; do not claim qualification from scripted tests.

## Comments

Added the internal, non-exported `lib/src/theme_formatted_components.dart`
`ThemeFormattedPrompt` seam with factories for Slider, RangeSlider, NumberInput,
PortInput, IPAddressInput, URLInput, EmailInput, ColorInput, DurationInput,
CronInput, MaskedInput, TagInput, DateInput, TimeInput and TimezoneSelect. Each
instance captures immutable configuration, owns one `ThemeSession`, resolves
mode and component colours in that period, emits sequential screen-reader
essentials before the real component, and delegates with the session handle.
No public constructor, factory, prompt signature or export changed.

TagInput's opening guidance now always advertises its component-safe help
route, including under hidden instructions; the exact linear transcript test
was updated for the added protected hint. State, validation, previews, masks,
cron review and domain values stay with the real components rather than a
second renderer, so their domain semantics are unchanged. Component palette
overrides are layered from the period's resolved palette; no per-invocation
session configuration was added.

Validation after `git merge --no-edit integration/adaptive-theme-presentation`
(reported `Already up to date.`):

- `dart test test/theme_formatted_components_test.dart -r compact` — 17 passed.
- Focused formatted-value regression set (the new suite plus slider, range,
  number, network, URL, email, colour, cron, date, duration, mask, time,
  timezone, tag and migration suites) — 295 passed.
- `dart format --output=none --set-exit-if-changed .` — 315 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5479 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Decisions: rich and linear hints remain with the real components; the themed
seam adds only screen-reader-before content. Live feedback can share the same
period and the shared reader is released once when the last participant ends.
Scripted tests cover identified pasted command-shaped text across invalid
retries, short-limit help/cancel, multiline-paste rejection with the draft
preserved, reader cleanup, range and numeric/port validation, leap-day and
timezone handling, cron preview, mask values, colour previews and tag editing.

Gaps: all evidence is scripted or synthetic. No native terminal, real screen
reader, human accessibility, real light/dark visual or platform-detection
check was performed, and no qualification is claimed. Bracketed-paste frames
are parsed by the existing shared reader and cleanup is observed, but no
hardware capability negotiation or enable/disable control sequence was added;
unframed paste still cannot be distinguished from typing. Human evidence and
release gates remain later tickets.
