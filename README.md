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

## Password

`Password('Password').prompt()` starts a fresh secret session. Enter ends
hidden editing, not submission: choose `submit`, `edit`, `clear`, `help`, or
`cancel` at the separate action stage. In linear mode `/help` and `/cancel`
are also available there; hidden entry always treats them literally. Empty
entry is an empty secret, and EOF never accepts a draft. Validation errors are
reported generically, so callbacks must not rely on displaying their messages.

No echo is the default. `mask: true` explicitly reveals length through mask
characters. `initialValue` explicitly retains a prefilled secret in memory;
reopening Edit retains it, while Clear starts empty. Both use the capable
shared editor, including in linear mode. Neither terminal echo flags nor the
scripted tests establish actual screen-reader typing behavior: terminal and
NVDA secret entry, masking, and prefill require separate verification. Avoid
real secrets in test transcripts and callback diagnostics.

## Multiline

`Multiline('Notes').prompt()` starts a fresh session. In rich mode Enter adds
an LF; Tab cycles Edit, Finish and Insert tab, and Enter activates the focused
action. Arrow keys move between graphemes and lines, Home/End move to line
boundaries, and Ctrl+T opens help. Escape dismisses help or an action before
cancelling; Ctrl+C interrupts. The focused line is displayed in place, with
literal tab characters shown as `?`.

In linear mode, Enter appends a logical line, including an empty line. `/list`
reviews lines; `/edit`, `/insert` and `/remove` ask for a line number in a
separate step; removal requires confirmation. `/done` validates and submits.
Exact `/help` and `/cancel` are also available. A backslash quotes an exact
command; double a leading backslash to enter one. For example, `\temp` remains
`\temp`, while `\\server\share` enters `\server\share`; use three leading
backslashes to enter a UNC pair. Identified framed paste is literal and does
not execute commands; unframed paste cannot be distinguished from typing.

Line endings in supplied, initial and framed pasted text normalize CRLF and CR
to LF. Blank lines and final blank lines are retained. `initialValue` is
editable, `required` and `validate` are checked on finish, and `maxLength`
counts grapheme clusters including line separators. Failed validation retains
the draft. EOF never submits. Framed paste is limited to 4096 UTF-16 code units
and oversized insertions are rejected. Native tests cover the Windows console
protocol, not actual clipboard or NVDA qualification.

### Autocomplete

`Autocomplete(label, suggestions: (query) => ...)` accepts independently valid
free-form text; suggestions may be synchronous or asynchronous. Rich Up/Down
inspects candidates, Tab accepts the active or first candidate, and Enter
accepts an active candidate or submits the text when none is active. Escape
first dismisses suggestions. Linear interaction offers numbered candidates,
`/edit`, `/submit`, `/help`, and `/cancel`; selecting a candidate does not
submit it. Quoted commands and identified paste are literal data. Unframed
paste cannot be distinguished from typing. `initialValue`, `required`,
`maxLength` (graphemes), and `validate` configure the answer constraints.

## MultiSelect

`MultiSelect<T>` returns selected identities in the original choice order. Empty
selection is valid unless `min` requires more; `max` rejects additions as a
whole. Defaults must identify enabled choices. In rich mode Space toggles the
focused item and Enter submits; `/` edits the label filter, Ctrl+A selects the
enabled filtered results, Ctrl+X clears them, and Ctrl+R reviews all selected
items. In linear mode `/filter` asks for filter text, a stable choice number
toggles that item, `/selected` reviews the entire selection and `/done` submits.
`/select-visible` and `/clear-visible` apply to enabled results across every
page, not hidden choices. Filtering matches labels case-insensitively.

A `SuppliedAnswer` is the complete selection as comma-separated stable choice
numbers, for example `2,1`; an empty string means the empty set. References
must be unique and enabled, without whitespace, and satisfy count constraints.
Supplied answers are literal and do not interpret prompt commands.

### SearchSelect

`SearchSelect<T>(label, choices, defaultValue: ...)` returns one enabled choice
identity. By default it searches choice labels with case-insensitive substring
matching in source order. Source numbers identify choices throughout the prompt,
including across filters and pages. Rich Enter or an arrow enters results from
query editing without accepting; Enter in results accepts the focused enabled
choice. Tab traverses query, results, and the Cancel action; typing from results
or the action returns to query editing. Linear interaction begins with a query,
then accepts a result reference; `/search` edits the query, `/list` reviews the
page, and `/next` and `/previous` page through results. `/help` and `/cancel`
are exact commands. Quoted commands and identified paste are literal; unframed
paste cannot be distinguished from typing.

An optional `search` callback replaces the default matching policy; applications
must describe their policy to users. It may return a `List<Choice<T>>` or a
future of one. Returned identities must be unique and already exist in the
configured choices; labels and disabled reasons may be updated. Results are
shown in original source order with the original references. Pending, failed and
obsolete searches cannot be accepted. If a previously focused result disappears
or becomes unavailable, rich interaction explains it and requires navigation
before selecting another result. Supplied references are unavailable with a
custom search because dynamic availability cannot be verified without a query.
