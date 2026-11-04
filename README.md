# Prompty

A Dart prompting-library project, currently at the design-to-implementation
stage. TextInput is the first public prompt component; other component APIs
are not implemented yet.

## TextInput

```dart
import 'package:prompty/prompty.dart';

final result = await TextInput(
  'Name',
  initialValue: 'Ada',
  required: true,
  maxLength: 80,
  validate: (text) => text.contains('@') ? 'Enter a name, not an address.' : null,
).prompt();

switch (result) {
  case Accepted<String>(:final value): print(value);
  case Cancelled<String>(): break;
  case Interrupted<String>(): break;
  case InputEnded<String>(): break;
  case Unavailable<String>(:final reason): print(reason);
}
```

Construction does not acquire the terminal. Each invocation starts a new
session; overlapping sessions on the same prompt or console are rejected.
Interactive console input currently requires Windows. Prompt output defaults to
stderr; pass `output: stdout` to select stdout. Redirected output is sequential,
without cursor addressing. Explicit rich mode requires terminal output and
fails rather than falling back. Mode precedence is `mode`, `userPreference`,
`applicationPreference`, then automatic capability selection.

Redirected stdin is never consumed implicitly. Supply a literal value with
`source: SuppliedAnswer(value)`, or explicitly opt into a stream with
`ScriptedInput(stream, sink, supportsRich: false)`. Supplied answers are literal
and validated. For a stream, only completed lines submit; EOF, cancellation and
interruption are distinct outcomes. Linear `/help` and `/cancel` are exact
commands: prefix either with `\` to enter it literally, and double an initial
backslash to enter one. Identified bracketed paste is literal; unframed paste
cannot be distinguished from typing. Paste frames are bounded to 4096 UTF-16
code units and oversized frames are rejected as a unit. Character limits count
grapheme clusters. Accessibility is not qualified by the automated tests;
see [the editable probe](docs/editable-probe.md) for evidence and limitations.

## Visual reference

Open [the 15 prompt structures](example/prototype-themes/structures.html) to
compare layout grammars, or browse [the 45-theme atlas](example/prototype-themes/index.html).
The complete folder is retained so the structure page's data, gallery links and
images work together. These are static visual references, not working prompts.

Open the HTML directly, or serve it locally:

```powershell
python example/prototype-themes/serve.py
```

Then visit <http://127.0.0.1:8765/structures.html>.

## Terminal backend and patch

The validated implementation direction is **Dart TUI (`dart_tui`)**, rather
than combining it with or extending the `dart_console` prototype backend.

**Important: the successful Windows trials used a local patch to Dart TUI
3.0.0.** Unmodified 3.0.0 failed exact echo/line-input restoration. Main records
the decision but does not install either backend or carry the patched package.

Read [the backend relationship, patch details and archived evidence](docs/terminal-backend.md).

## Components used to make the themes

The atlas depicts **40 named components** across 45 themes. See the
[complete component-name inventory](docs/theme-components.md), sourced directly
from the atlas generator. The structures page compares four of those components
across fifteen structures; neither inventory is a claim of implemented APIs.

## Archived prototypes

- Branch: `prototype/cli-theme-atlas`
- Commit: `8483a5a343bb595fdbeb3b3b5881e5233c285e90`

That commit preserves both backend trials, their real Windows-console tests,
and the locally patched Dart TUI snapshot. Main retains only the visual
references and the conclusions needed for implementation.

## Check the Dart package

```powershell
dart pub get
dart analyze
dart test
```

Windows native console regressions can also be run with the PowerShell scripts
in `test/`, including `text_input_windows.ps1`.
