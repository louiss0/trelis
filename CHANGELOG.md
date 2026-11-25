## 1.0.0-dev.1

Prerelease. The public API is **unstable**: the independent interaction and
colour release gates have not passed, and the human evidence they require is
still missing. Do not rely on API stability, accessibility qualification,
screen-reader usability or real-terminal colour quality from this version.

### Package rename

- The Dart package is renamed from `prompty` to `trelis` to match the
  project name. The package entry point moves from `lib/prompty.dart` to
  `lib/trelis.dart` and every import changes:
  `import 'package:prompty/prompty.dart';` ->
  `import 'package:trelis/trelis.dart';`.
- Historical rename migration guidance:
  `assets/evidence/trelis-package-rename/migration.md`. Note that its claim
  that nothing else changed was true at rename time only; the breaking
  cutover below landed afterwards.

### Breaking theme-instance cutover

- Components are now created through instances of the fifteen exported
  structural themes (`PlainTheme`, `RailTheme` and thirteen more). A theme
  owns one I/O environment and one lazy active period, and restores terminal
  resources after the last active component. There is no public theme
  `close()`.
- **Removed from the public API:** static theme component factories, public
  direct component constructors, invocation-level I/O/session/mode/
  presentation configuration (`source`, `output`, `terminal`,
  `outputProfile`, `session`, per-invocation `mode`), and the supplied-answer
  types `SuppliedAnswer` and `SuppliedTags`.
- `prompt()`, `present()` and `start()` are parameterless. I/O, mode, colour
  and resolution configuration are captured by the theme at construction.
- Non-interactive input is an explicit stream environment,
  `TerminalEnvironment.scripted`, whose bytes still pass through parsing,
  editing, validation, help commands and EOF handling. It is not
  behaviourally equivalent to the removed supplied-answer shortcut.
- The compact primary-action/help hint is now mandatory protected content;
  `InstructionDisplay.hidden` suppresses optional guidance only.
- Migration guidance: `docs/adaptive-theme-public-api-migration.md`.
- The pre-cutover constructor seam survives only inside
  `package:trelis/src/testing/compat_api.dart` for the internal component
  test suite. It is not public API and carries no compatibility promise.

### Key gestures

- In rich Multiline interaction, Enter inserts a newline into the draft (or
  activates the focused action) and Ctrl+J finishes the answer. Line-ending
  decoding is input-event-local: CRLF bytes delivered together in one input
  event are treated as Enter's newline gesture, while a separately delivered
  LF is the Ctrl+J finish gesture, so a finish keypress after Enter is no
  longer consumed by input decoding.
- F1 opens component- and stage-specific help in rich interaction; `/help`
  remains the linear route. Escape dismisses temporary help and restores the
  prior view and caret before it cancels.
- Framed (bracketed) paste is the lossless route for multiline pasted text;
  unframed paste cannot be distinguished from typing and its CRLF bytes act
  as key gestures.

### Component inventory

- 38 prompt and feedback component families over one public session seam:
  text and secret entry, multiline, autocomplete, tags, booleans, single and
  multiple choice, search, ordering, sliders, time, paths, filesystem
  pickers, key capture, numbers, ports and addresses, URLs, e-mail, colour,
  masks, durations, dates, cron, and progress, spinner and multi-task
  feedback.
- Every component supports a rich in-place interaction and a sequential
  linear one, with editable defaults, persistent validation guidance,
  reviewable final state and the layered `Accepted`, `Cancelled`,
  `Interrupted`, `InputEnded` and `Unavailable` outcomes.
- Windows and POSIX terminal backends own the selected input and output
  streams, check and restore native console state, reject concurrent sessions
  and refuse rich output on non-capable terminals such as `TERM=dumb`.
- Unicode measurement data comes from `termunicode` pinned exactly at
  `0.2.0` (Unicode 16 table basis). The exact pin is deliberate Unicode-data
  policy so tables cannot shift silently beneath applications; the resulting
  publish warning is an accepted tradeoff.

### Missing human evidence

- The interaction and colour release gates remain open `ready-for-human`
  work. No stable interaction, stable colour behavior, accessibility
  qualification or screen-reader usability is claimed.
- The whole-library Windows Terminal + NVDA baseline has not been performed.
  Component-level automated and native checks are recorded in
  `assets/ticket-31-regression-evidence.md`; they are not accessibility
  qualification.
- Automated publish dry-run output is recorded as evidence only in
  `assets/evidence/release-readiness/publish-dry-run.md`; it is not
  authorization to publish.
