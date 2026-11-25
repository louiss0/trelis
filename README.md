# Trelis

A Dart prompting-library project. The public API is currently **unstable**:
the coordinated theme-instance cutover has landed, but the independent
interaction and colour release gates have not. The package version is a
prerelease (`1.0.0-dev.1`) for exactly that reason: signatures, key gestures
and presentation behavior can still change before a stable release.
Components are created through theme instances, which own one I/O environment
and restore terminal resources after the last active component. There is no
public theme `close()`.

```dart
import 'package:trelis/trelis.dart';

final theme = RailTheme(io: environment);
final name = await theme.textInput('Name', initialValue: 'Ada').prompt();
```

See [the migration guide](docs/adaptive-theme-public-api-migration.md) for the
breaking changes from static factories, direct constructors, invocation-level
configuration and supplied answers. The older constructor-based seam still
exists for the internal component test suite; it is documented separately in
[the internal compatibility reference](docs/internal-component-compatibility.md)
and is **not** public authoring usage. Current scripts under `example/` and
`tool/` use public theme instances; only the GUI evidence fixture remains on
the internal session seam because it verifies that legacy rendering path.

## Using the public theme-instance API

Construct one of the fifteen exported structural themes (`PlainTheme`,
`RailTheme`, `AsciiTheme`, `DoubleTheme`, `ChevronTheme`, `ColonTheme`,
`BoxTheme`, `BracketTheme`, `BlockTheme`, `BranchTheme`, `RoundTheme`,
`LineTheme`, `MinimalTheme`, `FormTheme`, `LedgerTheme`) and keep it for the
active period of your application. A theme accepts optional named `io`,
`interaction`, `colors`, `selectionStyle`, `onResolved` and `hints`
arguments. When `io` is omitted the theme uses
`TerminalEnvironment.nativeThemeDefault`, which binds the handle-preserving
native console transport and re-observes the selected output's geometry and
colour facts on each use.

```dart
final theme = RailTheme(
  interaction: const InteractionPreferences(mode: PromptMode.linear),
);
final prompt = theme.textInput(
  'Name',
  initialValue: 'Ada',
  required: true,
  validate: (text) => text.contains('@') ? 'Enter a name, not an address.' : null,
);
final result = await prompt.prompt();

switch (result) {
  case Accepted<String>(:final value): print(value);
  case Cancelled<String>(): break;
  case Interrupted<String>(): break;
  case InputEnded<String>(): break;
  case Unavailable<String>(:final reason): print(reason);
}
```

Component methods create reusable prompts. `prompt()` takes no arguments:
I/O, mode, colour and session configuration belong to the theme, not to an
invocation. Reusing a prompt restarts from its configured initial value;
concurrent invocations of the same prompt are rejected. The five outcomes
are layered and reviewable: `Accepted` carries the validated value,
`Cancelled` and `Interrupted` are distinct user actions, `InputEnded` reports
input exhaustion or EOF, and `Unavailable` explains why the prompt could not
run (for example explicit rich interaction on a non-capable terminal).

Interactive console input requires a Windows console or a POSIX terminal;
hosts beyond Windows, Linux and macOS attempt the POSIX path on a best-effort
basis and refuse cleanly when their libc or signals cannot participate.
Redirected output is sequential, without cursor addressing. A terminal
declared `TERM=dumb` is not rich-capable even when it reports a terminal, so
explicit rich interaction returns an unavailable outcome instead of emitting
escape sequences. In automatic mode, interaction selection falls back to
linear when the output cannot support a cursor-addressed screen.

### Scripted input is an explicit stream environment

There is no supplied-answer API. Non-interactive input is provided by
constructing the theme with a scripted environment:

```dart
import 'dart:io';

final scripted = TerminalEnvironment.scripted(
  input: Stream.value('Ada\n'),
  output: stdout, // or any StringSink, such as a test buffer
  profile: const OutputProfile(colorDepth: ColorDepth.rgb),
  supportsRich: false,
);
final result = await RailTheme(io: scripted).textInput('Name').prompt();
```

This is an input **stream**, not a literal answer shortcut. Scripted bytes
still pass through input parsing, editing, validation, help commands and EOF
handling: values can be rejected or interpreted as commands, only completed
lines submit, and stream exhaustion produces `InputEnded` rather than an
instant answer. The migration guide explains why the removed `SuppliedAnswer`
shortcut must not be replaced with scripted I/O under the assumption of
identical results.

## Components

Every structural theme exposes the same component methods. Interactive
methods return a reusable `ThemePrompt<T>`; feedback methods return
`ThemeFeedback` or a live participant whose control is finished or stopped
explicitly.

| Method | Answer type | Purpose |
|---|---|---|
| `textInput` | `String` | single-line text |
| `password` | `String` | hidden secret entry with an action stage |
| `multiline` | `String` | multi-line text |
| `confirm`, `checkbox`, `toggle` | `bool` | booleans in three wordings |
| `select`, `radio` | `T` | single choice from `Choice` values |
| `multiSelect` | `List<T>` | multiple choices with optional bounds |
| `treeSelect` | `T` | single choice in a tree |
| `sortableSelect` | `List<T>` | ordering |
| `autocomplete` | `String` | free text with synchronous or asynchronous suggestions |
| `searchSelect` | `T` | search over choices |
| `slider` | `String` | exact decimal value in a step interval |
| `rangeSlider` | `(String, String)` | exact decimal range |
| `numberInput` | `NumericAnswer?` | locale-aware numbers |
| `portInput` | `int` | port numbers |
| `timeInput` | `({int hour, int minute, int? second})` | times |
| `tagInput` | `List<String>` | canonical kebab/snake-case tags |
| `maskedInput` | `MaskedValue` | structured formats |
| `colorInput` | `ColorValue?` | colours |
| `cronInput` | `CronExpression` | cron expressions |
| `durationInput` | `DurationValue` | durations |
| `dateInput` | `CivilDate` | dates |
| `timezoneSelect` | `String` | timezones |
| `ipAddressInput` | `IPAddressValue` | IP addresses |
| `urlInput` | `String` | URLs |
| `emailInput` | `String` | e-mail addresses |
| `pathInput` | `String` | paths |
| `filePicker`, `directoryPicker` | `String` | filesystem pickers |
| `keypress` | `KeyGesture` | single key capture |
| `keybind`, `joinedKeybind` | `List<String>` / `String` | key bindings |
| `text` | feedback | one presented line |
| `progress`, `spinner`, `multiSpinner` | live feedback | application-owned progress |

Detailed per-component behavior was written against the internal constructor
seam and now lives in
[the internal compatibility reference](docs/internal-component-compatibility.md).
The behavioral facts (key gestures, validation, paste and outcome semantics)
apply to the same components created through a theme; the construction
snippets do not.

## Interaction and input

### Rich and linear interaction

Every interactive component supports a rich in-place interaction and a
sequential linear one. In rich interaction the active answer is edited in
place with a visible caret; long answers scroll horizontally with `<` and `>`
markers for hidden text. A declared output geometry bounds editing and
wrapping within the narrower of that geometry and a documented 120-column
total-width cap, and Trelis never splits a grapheme to meet that bound. Idle
resize notifications reflow the painted line without editing the draft. In
linear interaction each exchange is sequential transcript text, so redirected
output stays reviewable.

### Help

F1 opens component- and stage-specific help in rich interaction on capable
terminals; `/help` is the linear route. Escape dismisses temporary help and
restores the previous input view and caret before it cancels anything. The
compact primary-action/help hint is protected content: an
`InstructionDisplay.hidden` policy suppresses optional editing guidance only,
never the route to help. Hidden-entry components keep F1 as that route
because a typed `/help` line is answer data there.

### Key gestures and line endings

In rich Multiline interaction, Enter inserts a newline into the draft (or
activates the focused action) and **Ctrl+J finishes the answer**; Ctrl+Enter
arrives as the same LF on the Windows console path. Line endings are decoded
input-event-locally: CRLF bytes delivered together in one input event are
treated as Enter's newline gesture, while an LF delivered separately from CR
is the Ctrl+J finish gesture. CR state never persists across input events, so
a later Ctrl+J cannot be consumed by an earlier Enter.

Framed (bracketed) paste is the lossless route for multiline pasted text:
CRLF and CR inside a paste frame normalize to newline data and never finish
the answer. Paste frames are bounded to 4096 UTF-16 code units and oversized
frames are rejected as a unit. **Unframed paste cannot be distinguished from
typing.** If a terminal coalesces two physical keypresses into one unframed
CRLF byte pair, the bytes are indistinguishable from pasted CRLF data; use
bracketed paste when multiline paste fidelity matters.

Line endings in initial and framed pasted text normalize CRLF and CR to LF.
Character limits count grapheme clusters. EOF never submits a draft, and
failed validation retains it.

### Linear commands

Linear `/help` and `/cancel` are exact commands: prefix either with `\` to
enter it literally, and double an initial backslash to enter one. Identified
framed paste is literal data and never executes commands.

## Accessibility status

Accessibility is **not** qualified by the automated tests. The whole-library
Windows Terminal + NVDA baseline has not been performed, and no screen-reader
usability, accessibility qualification or real-terminal colour-quality claim
is made. A focused human check of Password entry with real keyboard typing at
one historical revision completed both sessions without NVDA character or
length disclosure; that verifies one recorded Windows Terminal/NVDA
configuration only and is not a broader qualification. The interaction and
colour release gates remain open human work; see
[the editable probe](assets/editable-probe.md) for evidence and limitations.

## Visual reference

Open [the 15 prompt structures](assets/prototype-themes/structures.html) to
compare layout grammars, or browse [the 45-theme atlas](assets/prototype-themes/index.html).
The complete folder is retained so the structure page's data, gallery links and
images work together. These are static visual references, not working prompts.
The HTML and images live in `assets/`; the Python generator and local server
live in `tool/`, never in `example/`.

Open the HTML directly, or serve it locally:

```powershell
python tool/serve_theme_atlas.py
```

Then visit <http://127.0.0.1:8765/structures.html>.

## Terminal backend

Trelis uses its in-repo terminal/session backend with Dart FFI. For this
library's contract, it is a better fit than the evaluated Dart TUI 3.0.0
adapter: it owns the selected streams independently, exposes explicit EOF and
cancellation outcomes, checks and restores exact native state, supports repeated
sessions, and shares component semantics across rich and linear modes without a
patched general-purpose TUI runtime.

This is not a claim of universal superiority or completed accessibility. Dart
TUI retains general rendering and stock-model advantages; POSIX execution and
the whole-library NVDA baseline retain their recorded evidence gates. Read
[the requirements-based comparison, limitations and archived patch evidence](assets/terminal-backend.md).

## Components used to make the themes

The atlas depicts **40 named components** across 45 themes. See the
[complete component-name inventory](assets/theme-components.md), sourced directly
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

## Run one component

`example/` has one folder per structural theme. Each folder contains a file for
every one of the 38 components, so all **15 × 38 = 570** combinations are
available. Any file shows exactly **one** component with one structural theme
and one colour theme:

```powershell
dart run example/rail/text_input.dart
```

Add `--scripted` to replay a fixed answer without a terminal. The folder list,
component list and palette assignments are in
[example/README.md](example/README.md).

## Unicode data policy

Trelis pins `termunicode` exactly at `0.2.0` (Unicode 16 table basis) behind
its own measurement adapter. The pin is deliberate: grapheme, width and
property data must not shift silently beneath an application because a
transitive dependency constraint allowed a newer Unicode table. The exact
constraint produces a `dart pub publish` warning; that warning is an accepted
tradeoff of the Unicode-data policy, documented in the publish dry-run
evidence. Do not loosen the pin without a new Unicode-data policy decision.

## Release status and evidence

This package is a prerelease. The independent interaction and colour release
gates are still open human evidence work, so no stable API, accessibility
qualification, screen-reader usability or real-terminal colour-quality claim
is made. `dart pub publish --dry-run` output is recorded as release evidence
in [the publish dry-run evidence](assets/evidence/release-readiness/publish-dry-run.md),
including the accepted packaging warnings. That output is evidence only; it
is not authorization to publish, and this repository intentionally keeps its
Git-backed `docs/` issue tracker layout even though it produces a
documentation-directory publish warning.

## Compatibility and migrations

The package was renamed from `prompty` to `trelis`, and the public API then
changed breakingly for the theme-instance cutover. Static factories, public
direct component constructors, invocation-level I/O/session/mode
configuration, `SuppliedAnswer` and `SuppliedTags` are gone from the public
surface. Read [the migration guide](docs/adaptive-theme-public-api-migration.md)
for the supported migration and the changelog for the separated entries. The
internal constructor seam retained for component tests is documented in
[the internal compatibility reference](docs/internal-component-compatibility.md);
it is not a compatibility promise.

## License

MIT; see [LICENSE](LICENSE).
