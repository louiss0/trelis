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
without cursor addressing. On a cursor-capable terminal, TextInput keeps the active answer on one
editable line with the visible cursor at its editing position; instructions and
completed exchanges remain in the transcript. Long answers scroll horizontally;
`<` and `>` indicate hidden text on either side. A declared output geometry
bounds the editable line and wrapped read-only label, instructions, and
validation text; Trelis uses the narrower of that geometry and a documented
120-column total-width cap. It never splits a grapheme to meet that bound.
Without that capability, it prints sequential text and cursor-position reports.
Linear command quoting and validation are unchanged. Explicit rich mode requires
a rich-capable terminal output and fails rather than falling back. A terminal
declared `TERM=dumb` is not rich-capable even when it reports a terminal, so
explicit rich mode returns an unavailable outcome instead of emitting escape
sequences. Mode precedence is
`mode`, `userPreference`, `applicationPreference`, then automatic capability
selection.

For TextInput and Password, Ctrl+T opens temporary help in either mode on
VT-enabled Windows consoles and recognized xterm/screen/tmux/rxvt terminals.
Escape removes that help and restores the previous input view and caret;
a second Escape cancels. Interruption, EOF and input errors also close the
temporary help screen. Redirected, incapable or unrecognized outputs retain
help text in the transcript instead. Typed `/help` and Password action help
remain transcript responses, not temporary screens.

Redirected stdin is never consumed implicitly. Supply a literal value with
`source: SuppliedAnswer(value)`, or explicitly opt into a stream with
`ScriptedInput(stream, sink, supportsRich: false)`. `TextInput.prompt` also
accepts `terminal: TerminalIo` for an application-owned terminal adapter. It
provides the selected input/output, existing rich-capability observation and a
declared environment; `acquire()` returns a lease that Trelis restores after the
invocation. Do not combine that adapter with `source:` or `output:`. `Text`,
`Progress`, `Spinner`, and `MultiSpinner` can select its output with
`terminal:` without acquiring input. The legacy native invocation and
`ScriptedInput` forms remain supported until the later migration contract step.
Supplied answers are literal and validated. For a stream, only completed lines
submit; EOF, cancellation and interruption are distinct outcomes. Linear
`/help` and `/cancel` are exact commands: prefix either with `\` to enter it
literally, and double an initial backslash to enter one. Identified bracketed
paste is literal; unframed paste cannot be distinguished from typing. Paste
frames are bounded to 4096 UTF-16 code units and oversized frames are rejected
as a unit. Character limits count grapheme clusters. Accessibility is not
qualified by the automated tests; see [the editable probe](doc/editable-probe.md)
for evidence and limitations.

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
[the requirements-based comparison, limitations and archived patch evidence](doc/terminal-backend.md).

## Components used to make the themes

The atlas depicts **40 named components** across 45 themes. See the
[complete component-name inventory](doc/theme-components.md), sourced directly
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

`dart run example/prompty_example.dart` runs a short interactive flow across
several components; add `--scripted` to replay it from a fixed stream without a
terminal, or `--linear` to force sequential interaction.

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

A Windows Terminal + NVDA 2026.3 agent probe using synthetic `SendKeys`
produced partial character announcements and was not accepted as qualification
evidence. A follow-up human check with real keyboard typing at component
revision `bee96b4` completed both Password sessions with no NVDA character or
length disclosure. This verifies the recorded Windows Terminal/NVDA
configuration only; it is not a broader accessibility qualification.

## Confirm, Checkbox and Toggle

`Confirm('Deploy?')`, `Checkbox('Accept terms')` and `Toggle('Cache')` share one
boolean contract. Each takes an optional `initialValue` (default `false`) and
returns `PromptResult<bool>`. The opening line states the default and the current
draft in the kind's own words: `Yes`/`No`, `checked`/`unchecked` or `on`/`off`.

In rich mode `Y` and `N` change a Confirm draft while Space toggles a Checkbox or
Toggle; Enter submits, Ctrl+T opens help, Escape dismisses help before it
cancels, and Ctrl+C interrupts. In linear mode enter `yes`/`y` or `no`/`n`, or
submit an empty line to take the displayed default. An unparseable answer
restates the guidance and keeps the draft. `/help` and `/cancel` are exact
commands under the shared quoting rules, and no shortcut submits a draft. A
`SuppliedAnswer` accepts only yes/y/no/n and is otherwise unavailable. Each
boolean prompt also accepts an optional `ColorTheme`; styles are emitted only
when the selected `OutputProfile` permits colour and are suppressed by
`NO_COLOR`.

Boolean `prompt` invocations accept `terminal`, `outputProfile` and `session`
the same way as the shared editor. A rich synthetic source declares cursor
support and positive geometry through its profile. An attached prompt inherits
its explicit `TerminalSession` configuration and can remain active while
session feedback repaints.

## Select and Radio

`Select<T>('Choice', choices)` and `Radio<T>('Choice', choices)` take a required
list of `Choice(value, label, {disabledReason})` with unique identities and safe,
nonempty labels, plus an optional `defaultValue` that must be one of them. Both
return the chosen identity; `Radio` changes only how the list is presented.

Rich mode lists every choice with `[focused]`, `[default]` and
`[unavailable: reason]` markers. Up/Down move between choices, Enter accepts the
focused enabled choice, Ctrl+T opens help, Escape cancels and Ctrl+C interrupts.
Linear mode pages the list ten at a time, announces `Page n of m`, and accepts a
stable choice number, with `/next` and `/previous` for pages. A disabled or
out-of-range reference keeps the listing and explains why, and an accepted
answer prints `Accepted: <label>`. A `SuppliedAnswer` is a stable choice number
for an enabled choice; anything else is unavailable.

## Multiline

`Multiline('Notes').prompt()` starts a fresh session. In rich mode Enter adds
an LF; Tab cycles Edit, Finish and Insert tab, and Enter activates the focused
action. Arrow keys move between graphemes and lines, Home/End move to line
boundaries, and Ctrl+T opens help. Escape dismisses help or an action before
cancelling; Ctrl+C interrupts. The focused line is displayed in place, with
literal tabs shown as `\t` and backslashes escaped as `\\` so the draft remains
unambiguous in the plain ASCII profile.

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

`Multiline.prompt` accepts `terminal`, `outputProfile` and `session` the same
way as the shared editor, so a rich synthetic source declares cursor support and
positive geometry through its profile. The focused line is repainted inside the
declared width with `<`/`>` overflow markers around the caret, idle resize
notifications reflow that line without editing the draft, and component help
(`Ctrl+T` in rich mode, `/help` in linear mode) names the add-newline, finish,
insert-tab, review, limit and validation behaviour instead of generic
submit wording. An attached prompt inherits its `TerminalSession` configuration
and can stay active while session feedback repaints; session help owns painting
and restores the latest draft, caret and feedback on dismissal.

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

## TagInput

`TagInput('Tags')` collects canonical tags and returns
`PromptResult<List<String>>` in entry order. `style` selects kebab-case (the
default) or snake_case, `maxLength` limits each canonical tag in grapheme
clusters, and `validate` receives the canonical tag and returns an error string
or null. Every draft is canonicalised before it is added: camelCase, spaces,
underscores and surrounding separators all collapse to `new-tag`, and rich mode
prints `Preview: <canonical>` while you type. `SuppliedTags([...])` validates a
whole collection at once, rejecting invalid characters, duplicates and invalid
canonical forms.

In rich mode Enter adds the draft and Ctrl+X discards it. On an empty draft
Backspace focuses the last tag, Left/Right move between tags, Enter edits the
focused tag and Delete removes it. Tab focuses Finish and Enter then submits; a
leftover draft must be added or discarded first. Linear mode adds the entered
text, and `/list`, `/edit`, `/remove` and `/done` review, edit, remove and finish.
Empty, too long, punctuated, misplaced combining-mark, duplicate and
custom-validator failures each keep the draft and state the reason.

`TagInput.prompt` accepts `terminal`, `outputProfile` and `session` on the same
terms as `Multiline`, and its help names the add, focus, edit, remove, discard
and finish actions plus the canonical style, limit and validator. The unaccepted
draft remains visibly separate from the accepted tags across repaints, session
feedback updates and idle resize, and `Finish` still submits only the accepted
collection.

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

## MaskedInput

`MaskedInput` fills structured formats. A `MaskTemplate('code', [...])` names a
format built from `MaskSlot(description, accepts, {required})` and
`MaskLiteral(text)`; several templates make an input adaptive, and `initialValue`
is a validated `MaskedValue(template, slots, formatted, {interpretation})`. The
accepted value exposes `template`, `slots`, `formatted`, `raw` and the
interpretation used, and `interpretation` (`automatic`, `raw` or `formatted`)
states how the entered text should be read.

With one template, rich mode edits slot by slot and announces each slot's
description, content and focus; Escape cancels and Ctrl+C interrupts. Linear mode
offers `/edit` for one slot, `/value` for the whole formatted value, `/review`
and `/done`. With several templates an ambiguous value is listed with its slot
contents and the template is chosen by number, or through `/template` in linear
mode. Paste is accepted as single-line printable text and is rejected when it
exceeds the template capacity or the 4096-code-unit frame bound; a paste that
needs template resolution is listed rather than guessed. Decoding has a bounded
work limit, and exceeding it preserves the draft for correction.

MaskedInput is a format prompt, not a secret prompt: slot contents are shown.
Use `Password` for secrets.

### Slider and RangeSlider

`Slider` and `RangeSlider` accept exact ASCII decimal strings for `minimum`,
`maximum`, `step`, and values. Values must lie within the bounds and align to
`step` measured from `minimum`; no entry is rounded or clipped. Optional
`precision` limits the number of decimal places, and `units` is displayed as
context. `initialValue`, or the pair `initialLower` and `initialUpper`, is
optional and must satisfy the configured constraints. Range `minimumGap`
defaults to zero; endpoints retain their Lower and Upper identities.

In rich interaction Tab visits the value or endpoints, Edit actions, and Submit.
Arrow keys adjust a focused value without crossing bounds or the minimum gap;
inside an editor arrows instead move the text cursor. Enter opens or finishes
editing and activates Submit. Escape dismisses help or the current editor before
cancelling; Ctrl+T opens help and Ctrl+C interrupts. Linear range entry asks for
each endpoint and a separate review/submit. Invalid text remains editable.
A supplied range uses the literal `Lower,Upper` spelling, for example `2,8`;
it must satisfy the same constraints. EOF does not submit a draft.

## TreeSelect

`TreeSelect<T>` accepts a hierarchy of `TreeNode<T>` and returns one node's
identity. Identities must be unique throughout the tree. A node with children
is not selectable unless `selectable: true` is explicit; a leaf is selectable
unless explicitly disabled for selection. `disabledReason` prevents choosing a
node but does not prevent traversing its children. Labels and reasons must be
nonempty safe text. The hierarchy is snapshotted at construction; create a new
component when the application has a different tree. For a changing source,
pass `isCurrent` to recheck every node in the path before opening or accepting;
a removed node is reported as unavailable and is never replaced automatically.
An unresolved branch can be represented with `childrenUnavailableReason`; it is not treated as a leaf,
and attempting to open it reports the reason. This API does not load children.

In rich mode Up/Down visit visible nodes, Right expands a branch or enters its
first child, Left collapses a branch or goes to its parent, and Enter chooses
only a selectable enabled node. In linear mode `/open` requests a reference
and enters a branch, `/up` returns to its parent, and `/choose` requests a
reference and accepts that node if permitted. Full paths and branch, selection
and unavailable states are shown as text. References are assigned once in
preorder and remain stable during a session, including when branches close.
`SuppliedAnswer` is one such numeric reference and is always literal. `/help`
and `/cancel` are exact commands; quote a command with a backslash, and double
a leading backslash. Identified paste is literal; unframed paste cannot be
distinguished from typing. EOF never accepts a partial command or answer.
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

### SortableSelect

`SortableSelect<T>(label, choices)` returns every supplied identity in the
chosen order. Choice identities must be unique. A choice with `disabledReason`
is a locked anchor: it remains in the result at its original position and other
items cannot cross it. Its reason remains visible.

In rich interaction, Space picks up or drops an item; Up/Down move it while
picked up, and Enter drops it before a second Enter submits. Escape reverts the
current move, then cancels at the root. In linear interaction, `/move` asks
for the stable original choice reference and then the destination position;
`/done` submits. References do not change when positions change. `/help` and
`/cancel` are exact commands. A backslash quotes an active command or a leading
backslash; other backslashes remain literal (for example `C:\work` and a UNC
path entered with its leading backslash doubled). Identified paste is literal.
A supplied answer is a comma-separated complete permutation of original numeric
references, subject to the same anchor rules; an empty list uses an empty string.

## CommandPalette

`CommandPalette('Commands', [Choice('save', 'Save')]).prompt()` returns a
`PromptResult` containing the accepted choice identity. The application decides
whether and how to execute that identity after acceptance; the palette does not
receive or invoke command actions. Identities must be unique. A `Choice` may
supply a `disabledReason`; unavailable commands remain visible but cannot be
accepted.

By default matching is case-insensitive substring matching in source order.
Rich interaction separates query editing from result acceptance: Enter first
opens results, and a subsequent Enter accepts the focused enabled command.
Linear interaction asks for a query and then a stable source reference; `/search`
edits the query. Neither unmatched query text nor an unavailable reference can
be accepted as a command. Escape in rich mode and `/cancel` in linear mode
cancel without acceptance.

An optional `search` callback may provide updated choices from the original
identities, including availability. Results are displayed in source order, not
callback order; pending, failed, obsolete, unknown or duplicate results cannot
be accepted. Supplied answers are source references and are unavailable when
using dynamic search because availability cannot be verified.

## DateInput

`DateInput('Date', order: DateFieldOrder.dayMonthYear)` returns a `CivilDate`
with `year`, `month`, `day`, the entered `inputYear`, `calendar`, `era` and
`monthIdentity`. `order` must be given whenever `calendar` or `digits` is
overridden, because the system profile is used only when no explicit order is
supplied; an unresolved or unsupported system profile returns `Unavailable`
instead of guessing. Supported profiles are Gregorian CE 0001-9999 and Buddhist
era 2484-9999 with Gregorian-derived months, ASCII plus `thai` or
`arabicIndic` digits (one repertoire per field), a four-digit year, one or two
digit month and day, and slash separators. Values are date-only civil
arithmetic: no timezone, instant or leap-month context is implied.

Rich mode edits three labeled segments. Tab or slash moves forward, Shift-Tab or
Ctrl+B moves back, Up/Down or `+`/`-` adjust the focused segment without carry,
and Enter advances or reviews. Linear mode edits the whole slash-separated
draft. Both review the parsed date and its ISO spelling before `/submit` or
`/edit` accepts or returns to the draft, and `/cancel` cancels. Errors name the
offending field, width, repertoire or calendar range and keep the draft.

Automatic resolution is narrow: Windows reports one full-year numeric short-date
profile, Gregorian or Buddhist, with ASCII, Thai or Arabic-Indic digits, and the
Linux and macOS attempts cover the same narrow numeric full-year profiles. Any
unsupported or ambiguous system setting requires an explicit override. Buddhist
conversion is an independent arithmetic implementation informed by ICU 76.1
`icu4c/source/i18n/buddhcal.cpp` (release-76-1), which maps Buddhist to extended
Gregorian year by subtracting 543; it is not an ICU provider or a qualification
of ICU behavior. The provider is qualified only for its stated bounded profiles,
and accessibility qualification has not been performed. See
[DateInput evidence](doc/date-input-evidence.md).

## CronInput

`CronInput('Schedule', profile: CronProfile.unix)` requires an explicit dialect:
five fields for `unix`, six or seven for `quartz`, including Quartz day-of-month
and day-of-week rules, `L`, `LW`, `L-n`, `W`, `#` and weekday `L`. Expressions are
limited to 4096 UTF-16 code units, must have no leading or trailing space, and
are validated before review; Quartz years are bounded to 1970-2199. Invalid
input keeps the draft for correction.

An optional `preview` adds matching-preview review. `CronPreviewConfig` requires
a zone, a UTC `reference` and `start`/`end` horizon, a `count`, a `budget` and a
positive `providerTimeout`; an out-of-range configuration is rejected at
construction. After an expression is entered, rich review offers Edit, Preview
and Submit and re-announces the current action after every preview round, while
linear review uses `/edit`, `/preview` and `/submit`. A preview reports its
status (`complete`, `horizonReached`, `budgetExhausted`, `cancelled`,
`providerError`, `providerTimedOut` or `unsupportedRange`) with the zone,
reference, horizon, count, budget, provider timeout and the instants it found.
Ctrl+C interrupts; Escape in rich mode or `/cancel` in linear cancels the preview
and returns to the retained expression, where a second cancellation ends the
prompt. A preview is civil-time matching, not scheduler execution. Provider
identity, work bounds and the unqualified dialect gaps are recorded in
[doc/cron-preview-evidence.md](doc/cron-preview-evidence.md).

### TimeInput

`TimeInput('Start')` accepts strict 24-hour `HH:mm` time-of-day values.
Set `seconds: true` to require `HH:mm:ss`, or `twelveHour: true` to
require a space and uppercase `AM` or `PM` with hours `01` through `12`.
These options may be combined. `initialValue` uses the configured format and
is editable. The accepted record contains a 24-hour `hour`, `minute`, and
nullable `second`; it does not contain or imply a date, timezone or instant.

Rich interaction uses Tab to reach labeled segments, formatted editing and
Submit. Up/Down or `+`/`-` adjust the focused segment without carry or wrap;
formatted editing is available through the Edit action. Enter a valid formatted
value before adjusting segments. Linear interaction accepts the same exact
format, retaining invalid drafts for correction. Terminal and screen-reader
support is subject to the qualifications documented above.

### TimezoneSelect

`TimezoneSelect('Zone')` returns a canonical IANA zone identifier, never a UTC
 offset. Its bundled identifier and alias snapshot is generated from the Zone
and Link records in IANA [tzdata2025c](https://data.iana.org/time-zones/releases/tzdata2025c.tar.gz),
including `backward`, ordered by canonical identifier. Search is
case-insensitive substring matching over identifiers, city labels (underscores
rendered as spaces), and aliases. Alias defaults resolve to the corresponding
canonical identity; unknown defaults are rejected. The optional `unavailable`
map gives zone identifiers or aliases and reasons; unavailable choices cannot be
accepted. No offset previews are provided, so there is no reference instant or
claim about scheduling. No network, system timezone, or clock is consulted by
the prompt. IANA data is maintained by IANA and distributed in the public domain.
### PathInput

`PathInput` accepts a literal native path and captures a stable absolute base at
prompt start (or uses the caller's absolute `base`). It shows the resolved
candidate for confirmation before returning it. Relative paths retain `..`
segments; there is no shell expansion, quote stripping, link canonicalization,
or working-directory change. Drive-relative Windows paths are rejected.
Existing targets are required by default. `allowNonexistent: true` explicitly
permits prospective paths; `target` can require a file or directory when the
target exists. With `allowNonexistent` and `PathTarget.any`, no filesystem
inspection is performed. Existence and type checks are snapshots, not a
promise that a later operation will succeed. Linear mode uses the shared
command quoting rules; double an initial backslash (three for a UNC pair).

For existence and typed-target checks, PathInput treats filesystem inspection
errors as errors rather than assuming the path is absent. A prospective typed
path is accepted only when the platform can establish absence; unsupported
inspection platforms fail closed. These checks are snapshots and do not grant
permission or guarantee a subsequent filesystem operation.

## FilePicker and DirectoryPicker

`FilePicker('File', base: path)` returns the absolute path of an existing file
and `DirectoryPicker('Directory', base: path)` of an existing directory. `base`
is the starting directory and defaults to `Directory.current.path`; it is not a
sandbox, so `parent` and `path` can leave it. Nothing is opened, changed or
created.

Both prompts are command-driven in rich and linear modes: `open <n>` enters a
listed directory, `choose <n>` chooses a listed entry, `path` enters a literal
path, and `parent`, `refresh` and `hidden` change the listing context. Entries
are listed with their type. A listing failure keeps the current context and a
choice is reviewed before it is returned; entering anything at that review
returns to the listing. A replaced entry is detected as stale and refreshes
instead of targeting the replacement. Linked directories need an explicit
`open <n> links` approval, linked cycles and unresolvable links retain the
current directory, and path validation errors are reported without losing
context. For `DirectoryPicker`, `choose` without a number chooses the current
directory.

### Feedback

`Text('Saved', kind: TextKind.success).present()` writes literal semantic text.
`Progress('Download', total: 100)` and `Spinner('Connecting')` are explicitly
started with `start()`, updated by the application, and finalized with
`finish(FeedbackOutcome.completed)` or another explicit outcome. A null total
is indeterminate; `setTotal` reports recalculation. `dispose()` releases the
presentation without asserting success. Feedback defaults to stderr and never
reads input or controls the operation. Linear progress defaults to ten-percent
milestones and a five-second intermediate interval; both are configurable.
Static rich output is available with `PromptMode.rich` on capable outputs;
redirected output defaults to linear. No color or animation is required.

Rich feedback uses a static `[status]` layout, appending each actual state
rather than addressing a cursor. This preserves complete task names and details
when the terminal wraps or is resized and avoids overwriting other output; it
is not an animated display. Linear output remains milestone-throttled and
reviewable. Select `mode`, `userPreference`, or `applicationPreference` at
`start()`; explicit rich mode requires a capable output.

### NumberInput

`NumberInput` is integer-only by default; set `decimal: true` for exact finite
base-ten decimals. Without an explicit `convention`, it resolves the effective
noncurrency system settings on each invocation: Windows user overrides, the
current macOS `NSNumberFormatter` preferences, or Linux `LC_ALL`/`LC_NUMERIC`/
`LANG` precedence. C/POSIX is a supported ungrouped ASCII convention, not an
error. Unsupported or unstable settings return `Unavailable`; they never fall
back to US formatting. A `convention` is an explicit override, while a
`conventionProvider` can supply application-specific resolution. One resolved
snapshot remains active for the whole prompt, so preference changes affect only
the next invocation.

Instructions state required/optional state, mode, separators, exact bounds and
precision, and concrete ASCII/native, grouped/ungrouped, positive and negative
examples before editing. Accepted `NumericAnswer` values retain the original
`spelling` and exact base-ten `coefficient`/`scale` without binary rounding.
Malformed grouping, mixed digit scripts, alternate signs, exponents, currency,
percent and special values are rejected rather than normalized.

### Port and IP address entry

`PortInput` accepts ASCII decimal ports 1-65535. Set `allowZero: true` only
when zero means a caller-defined automatic allocation/bind request. It does
not check availability or bind a socket.

`IPAddressInput` accepts numeric IPv4 and IPv6 without resolving hostnames or
checking reachability. Set `cidr: true` to require an address and prefix;
`IPAddressValue` preserves the original `spelling`, parsed `address`, and
`prefixLength` without masking host bits. Set `scoped: true` to allow an IPv6
zone, written `%` followed by ASCII letters, digits, underscore, hyphen, or
dot. The separate `zone` is environment-dependent and is not checked for
interface existence. Brackets and URL escaping are not interpreted.

### URLInput and EmailInput

Domain processing uses a pure-Dart UTS #46 provider with checked-in Unicode
16.0.0 tables. It implements STD3, hyphen, Bidi, ContextJ/ContextO, NFC and
Punycode checks, nontransitional processing and DNS-length verification
without native libraries. The source URLs are recorded in
`lib/src/uts46.dart`; the Unicode license is in `lib/src/uts46_LICENSE`.
This is local syntax processing, not a DNS or reachability check.

### ColorInput

`ColorInput('Color', required: false)` accepts optional absence as `null`;
`transparent` instead returns transparent black. `ColorValue.source` preserves
exact accepted spelling and can be passed as `initialValue` for re-editing.
Its `red`, `green`, `blue`, and `alpha` fields are normalized binary64 values
in 0�1, not 8-bit channels; HSL additionally provides normalized `hue` in
degrees. Binary64 arithmetic and HSL conversion are approximate, while the
source expression remains unchanged.

The declared CSS Color 4 sRGB subset is ASCII only: #RGB, #RGBA, #RRGGBB,
#RRGGBBAA (alpha last), the 148 static CSS named colors and `transparent`, and
literal `rgb`/`rgba` and `hsl`/`hsla` functions, case-insensitively. Modern
space-separated channels permit slash alpha and mixed RGB number/percent
channels; legacy comma-separated RGB channels must all use the same units.
HSL saturation and lightness require percentages. Hue accepts unitless degrees,
`deg`, `grad`, `rad`, or `turn`, and is interpreted modulo 360 degrees. Alpha is
0�1 or 0�100%; RGB channels are 0�255 or 0�100%; saturation/lightness are
0�100%. Out-of-range values are rejected, not clamped. Decimal numbers use
ASCII digits, optional sign and decimal point, with at most 12 digits per
number; exponent notation is excluded. Outside whitespace, comments, CSS
expressions, variables, contextual/system colors, relative colors and other
color spaces are excluded. No value is silently repaired.

Both rich and linear entry show textual sRGB, alpha, and normalized HSL hue as
valid drafts are entered. Rounded hex is explicitly an approximate preview and
never replaces the answer. No color perception is needed.

### Key capture

`Keypress` captures one logical gesture; `KeyChordInput` captures a nonempty
ordered sequence. In rich mode, `c` arms one capture, `d` declares, `r`
removes the last gesture, `x` clears, and Enter submits. In linear mode use
`/capture`, `/declare`, `/remove`, `/clear`, and `/done`; `/cancel` cancels.
Every capture returns to review: it never submits automatically. Escape exits
armed capture before cancelling the prompt; Ctrl+C interrupts. These two
reserved gestures cannot be captured live.

Declarations use `+` between modifiers and key (for example `Ctrl+Shift+A`);
for supplied `KeyChordInput` answers, separate gestures with commas. Modifiers
are `Ctrl`, `Alt`, `Shift`, and `Meta`, each at most once. Keys are ASCII
letters or digits, `F1` through `F12`, `Enter`, `Tab`, `Escape`, `Space`,
`Backspace`, `Delete`, `Insert`, `Home`, `End`, `PageUp`, `PageDown`, and
`ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`. Declarations are unverified;
`KeyGesture.warnings` identifies this and reserved declarations. They do not
prove future delivery or absence of conflicts. `requireObservation` rejects
declarations and ambiguous stream captures. Key spelling is not normalized:
letters in declarations retain their entered case, legacy byte-stream captures
retain the received character's case, and Windows observations use uppercase
virtual-key letters, including when Shift is reported. Compare keys with this
source-dependent casing in mind.

On the Windows console, key-down records supply virtual key and modifier state;
repeated key-down records for a held key do not create additional captures.
Only the bounded vocabulary above is represented. Windows-key state is tracked
while this prompt owns the console; a Meta key already held before the prompt
started may not be reported, so its absence is not proof it was not held.
Terminal and OS interception, keyboard layouts, AltGr, and remote transports
can change what arrives; this is not
physical-key identification or global hotkey registration. Legacy byte-stream
captures are marked `ambiguous` because the stream does not reliably identify
all modifiers. Their empty modifier set must not be interpreted as proof that
no modifier was held.

### DurationInput

Select `DurationInputMode.elapsed` or `DurationInputMode.calendarRelative` when constructing the input; entry never changes the mode. Supply one or more space-separated, case-sensitive tokens such as `1h 30m` or `1y 2mo 0.5s`. Amounts use ASCII digits and optional dot fractions, with no grouping; units cannot repeat. A sign is permitted only with `signed: true`, and applies to the entire expression. The original spelling is retained in `DurationValue.draft`.

Elapsed tokens are `w d h m s ms us`. A day is exactly 24 hours and a week seven days. Calendar-relative mode additionally accepts `y mo`; its `y mo w d` amounts must be whole and remain unapplied components. Sub-day amounts are elapsed quantities. No date, zone, application order, DST policy, endpoint or total is inferred for a period.

Fractions must convert exactly to integer microseconds; there is no rounding. The maximum magnitude is 9223372036854775807 for the elapsed total and for each calendar component, and drafts are limited to 1024 characters. The default is nonnegative, with zero accepted. `signed: true` permits a global sign; `minimumMicroseconds` optionally bounds elapsed values. `allowZero: false` rejects an all-zero value in either mode; calendar periods have no arbitrary built-in ordering or elapsed minimum. Microsecond resolution does not promise scheduler accuracy. Rich and linear input both show a textual interpretation while editing; invalid drafts remain editable.

### Concurrent task feedback

`MultiSpinner` presents application-owned work without reading input, taking
focus, or cancelling operations. Supply unique, nonempty task names in their
stable display order, then start presentation explicitly:

```dart
final jobs = MultiSpinner(['build', 'tests']);
jobs.start(); // stderr by default
jobs.update('build', TaskActivity.running, phase: 'compiling');
jobs.finishTask('tests', FeedbackOutcome.failed, detail: 'assertion failed');
jobs.finishTask('build', FeedbackOutcome.completed);
```

Each task begins waiting. `update` reports waiting or running and an optional
phase (which can include a meaningful progress value); updates are coalesced
across the entire group, by default at most once every five seconds. The
`interval` constructor argument changes this cadence. Final outcomes are
reported immediately and cannot be overwritten by late updates. Once all tasks
finish, the ordered summary retains every outcome and detail. Disposing earlier
prints a summary with unfinished tasks still waiting or running; it does not
claim success. Output is literal-safe and static in rich and linear modes, and
redirected output remains reviewable text. Mode selection and explicit output
use the same `start` arguments as other feedback components.

## License

MIT; see [LICENSE](LICENSE).
