# Trelis package rename — migration guidance

**Status:** published with the package rename
**Package:** `trelis` (formerly `prompty`)

## What changed

The Dart package is renamed from `prompty` to `trelis` to match the project
name. Nothing else changed: no component, API, behavior, theme, palette or
outcome was modified. This is a packaging and naming migration only.

- Package name: `prompty` → `trelis`
- Entry point: `lib/prompty.dart` → `lib/trelis.dart`
- Imports: `package:prompty/prompty.dart` → `package:trelis/trelis.dart`
  (`package:prompty/src/...` → `package:trelis/src/...`)

## One-line consumer migration

```dart
- import 'package:prompty/prompty.dart';
+ import 'package:trelis/trelis.dart';
```

Update the `prompty` dependency to `trelis` in `pubspec.yaml`:

```yaml
dependencies:
  trelis: ^1.0.0
```

## Unchanged

- The 38-component public surface and every constructor signature, generic
  parameter, callback, answer type, command and the five `PromptResult`
  outcomes (`Accepted`, `Cancelled`, `Interrupted`, `InputEnded`,
  `Unavailable`).
- The 15 structural themes (`PlainTheme`, `RailTheme`, `BranchTheme`,
  `BoxTheme`, `RoundTheme`, `DoubleTheme`, `MinimalTheme`, `AsciiTheme`,
  `ChevronTheme`, `BracketTheme`, `FormTheme`, `LedgerTheme`, `ColonTheme`,
  `LineTheme`, `BlockTheme`) and the 45 named palettes.
- Rich and linear interaction, presentation recording, and the shared session
  seam.

## Out of scope

- Whole-library accessibility / NVDA qualification.
- Universal terminal/font width correctness.
- Actually publishing `trelis` to pub.dev (requires separate authorization).
