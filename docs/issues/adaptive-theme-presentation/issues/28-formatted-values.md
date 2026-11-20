# 28 Migrate formatted value prompts

Status: ready-for-agent

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

- [ ] Exercise every listed real component in rich, linear and screen-reader modes, preserving typed values, formatting, validation, ranges, defaults and domain-specific operations.
- [ ] Communicate focus, current value, validation, selection and status without color; cover Unicode, ASCII, `NO_COLOR` and narrow layouts, including textual screen-reader states.
- [ ] Show mandatory compact primary-action/help hints at rich bottom and after normal linear content, and essential screen-reader instructions before each prompt despite hidden instructions; detailed help preserves draft, focus and caret.
- [ ] Independently verify editing and paste safety for applicable fields: escaped or identified pasted command-shaped values survive invalid retries, help/cancel work despite short value limits, and recognized multiline paste is rejected in single-line fields without losing draft; capability-check and clean up paste reporting.
- [ ] Test representative range bounds, numeric/port validation, temporal and timezone handling, cron parsing/preview, masks, color values and tag editing without changing existing domain semantics or exposing unsafe content.
- [ ] Route composite/delegated editors through the theme owner without registering a second external prompt; respect resolved interaction and component color overrides rather than adding per-prompt session configuration.
- [ ] Test acceptance, validation failure/retry, cancellation, interruption, unavailable and `InputEnded`; sequential reuse returns to configured initial values, and concurrent prompt use is rejected.
- [ ] Add automated family and session regressions, record commands/results and unperformed native-terminal or human screen-reader checks; do not claim qualification from scripted tests.
