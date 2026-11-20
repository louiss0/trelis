# 08 Build an internal end-to-end text input tracer

Status: resolved

**Blocked by:** [04](04-colour-resolution.md), [06](06-automatic-cleanup.md), [07](07-coordinated-feedback.md)

**What to build:** Exercise one internal theme-owned text input end to end through selected I/O, interaction and colour resolution, automatic lifecycle and coordinated feedback. This is a tracer, not the breaking public cutover or migration of every family. Preserve existing public calls and editor safety. See the [spec](../spec.md) and [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(io: scriptedEnvironment, colors: colors);
final name = theme.textInput('Name', colors: ComponentColors.palette(palette));
final result = await name.prompt();
```

## Acceptance criteria
- [x] Script rich and linear successful input through the owner, selected output profile and palette overrides, including concurrent feedback; assert output and resulting value.
- [x] Exercise reuse from configured initial value, EOF as `InputEnded`, rejected concurrent prompt and a later active period with fresh resolution; callback fires once per successful period.
- [x] Test callback, output and cleanup failures, no-colour and redirected output without leaks or lost primary outcome; caller-owned streams remain open.
- [x] Cover existing text editor and paste safety in affected paths, including literal escaped command-shaped input, retries, multiline paste rejection and secret non-disclosure where applicable; record tests and distinguish scripted evidence from native/human checks.

## Comments

Added the internal, non-exported `lib/src/text_input_tracer.dart`
`ThemeTextInputTracer` seam. It captures component configuration, layers
`ComponentColors` over the period's resolved palette with `resolveColors`, and
drives `TextInput` or `Password` through `ThemeSession`'s owned session. Live
feedback joins the same period. No public barrel export, theme factory, prompt
signature or close method was added.

Validation after merging `integration/adaptive-theme-presentation` (merge
reported `Already up to date.`):

- `dart test test/theme_text_input_tracer_test.dart -r compact` — 14 passed.
- `dart test -r compact` — 4979 passed.
- `dart format --output=none --set-exit-if-changed .` — 249 files, 0 changed.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Decisions: component overrides are applied inside the active period so a later
period re-resolves them; the period's selected background is carried forward
rather than queried twice. Callback, writer and period-cleanup failures are
observed at the tracer seam; a successful answer survives a period cleanup
failure and caller streams remain open. Scripted input covers an escaped
command after a required-field retry, multiline paste rejection with draft
retention, and secret output non-disclosure.

Gaps: all evidence is scripted. No native terminal, real reader, human
accessibility, real light/dark terminal or bracketed-paste hardware check was
performed. A failure while restoring the prompt's own adapter lease remains
the existing `TextInput`/`ThemeSession` behavior and was not changed here; the
tracer injects period cleanup failure separately. The public cutover and other
component families remain later tickets.
