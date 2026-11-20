# 08 Build an internal end-to-end text input tracer

Status: claimed

**Blocked by:** [04](04-colour-resolution.md), [06](06-automatic-cleanup.md), [07](07-coordinated-feedback.md)

**What to build:** Exercise one internal theme-owned text input end to end through selected I/O, interaction and colour resolution, automatic lifecycle and coordinated feedback. This is a tracer, not the breaking public cutover or migration of every family. Preserve existing public calls and editor safety. See the [spec](../spec.md) and [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(io: scriptedEnvironment, colors: colors);
final name = theme.textInput('Name', colors: ComponentColors.palette(palette));
final result = await name.prompt();
```

## Acceptance criteria
- [ ] Script rich and linear successful input through the owner, selected output profile and palette overrides, including concurrent feedback; assert output and resulting value.
- [ ] Exercise reuse from configured initial value, EOF as `InputEnded`, rejected concurrent prompt and a later active period with fresh resolution; callback fires once per successful period.
- [ ] Test callback, output and cleanup failures, no-colour and redirected output without leaks or lost primary outcome; caller-owned streams remain open.
- [ ] Cover existing text editor and paste safety in affected paths, including literal escaped command-shaped input, retries, multiline paste rejection and secret non-disclosure where applicable; record tests and distinguish scripted evidence from native/human checks.
