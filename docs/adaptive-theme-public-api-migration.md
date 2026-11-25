# Migrating to the unstable theme-instance API

This guide covers the coordinated breaking cutover for adaptive-theme
presentation ticket 32. The new public API is **unstable**: the interaction and
colour release gates have not passed, and native/screen-reader evidence is
still missing. Treat the signatures as a reviewable cutover, not as an
accessibility or long-term compatibility guarantee. While those gates remain
open the package version is a prerelease (`1.0.0-dev.x`); depending on it
requires an explicit prerelease constraint such as `trelis: 1.0.0-dev.1`,
because caret constraints like `^1.0.0` do not select prerelease versions.

BREAKING CHANGE: static theme component factories, public direct component
constructors, invocation-level I/O/session/mode/presentation configuration,
`SuppliedAnswer` and `SuppliedTags` are no longer part of the public API.
Callers must construct a theme instance and call its instance methods; the
remaining sections describe the migration and its supported alternatives.
The GUI evidence fixture intentionally keeps using the internal compatibility
session seam to verify the legacy rendering path; it is not public usage and
is not a second supported API.

## Before and after

```dart
// Before: static factories and per-invocation configuration.
final name = await RailTheme.textInput(
  'Name',
  colors: ColorThemes.paper,
).prompt(source: SuppliedAnswer('Ada'), mode: PromptMode.linear);

// After: one reusable theme owns the environment and active period.
final theme = RailTheme(
  io: environment,
  interaction: const InteractionPreferences(mode: PromptMode.linear),
);
final prompt = theme.textInput(
  'Name',
  colors: ComponentColors.palette(ColorThemes.paper),
);
final result = await prompt.prompt();
```

The 15 structural themes are `PlainTheme`, `RailTheme`, `AsciiTheme`,
`DoubleTheme`, `ChevronTheme`, `ColonTheme`, `BoxTheme`, `BracketTheme`,
`BlockTheme`, `BranchTheme`, `RoundTheme`, `LineTheme`, `MinimalTheme`,
`FormTheme` and `LedgerTheme`. Every one is an instance with optional named
`io`, `interaction`, `colors`, `selectionStyle`, `onResolved` and `hints`
arguments. All 34 interactive families and four feedback families are instance
methods. There are no static component factories and no public direct component
constructors in `package:trelis/trelis.dart`.

## Parameterless prompt calls

`prompt()` takes no arguments. I/O, selected output, output profile, mode,
session and resolution callbacks are captured by the theme, not by an
invocation. A prompt can run again sequentially and restarts from its
configured initial value; concurrent calls on the same prompt are rejected.
Scripted input exhaustion returns `InputEnded`. A live feedback component can
stay active while one prompt runs, and the terminal is restored automatically
after the final active component ends. There is no `theme.close()`.

## Feedback

```dart
await theme.text('Saved', kind: TextKind.success).present();

final control = await theme.spinner('Working').start();
// ... application work ...
await control.finish(FeedbackOutcome.completed);
// or await control.stop() when there is no truthful outcome to report.
```

`present()` and `start()` are asynchronous because the theme resolves the
active period before any output. Feedback does not display an artificial help
hint.

## Creation captures configuration

Component and live-feedback methods build the underlying component when they
are called. Collection arguments - choice lists, multi-select defaults,
supplementary help lines and `multiSpinner` task names - are snapshotted at
that point, so later caller-side mutation of the original collections cannot
change a created prompt. Reusing a prompt reruns the same configuration.

## Native environment default

When no `io` is supplied the theme uses `TerminalEnvironment.nativeThemeDefault`,
which binds the handle-preserving native console transport rather than a Dart
stdin subscription. Each prompt still acquires and restores its own native
lease - echo, line mode and VT input handling stay with the existing per-prompt
transport - and the environment's output profile is re-observed from the
selected output on each use. The marker stream is never subscribed, so the
session-owned background query is unavailable for the default environment;
background resolution then falls back to the passive hint and the dark default.
A custom `TerminalEnvironment` with a real input stream remains the seam for
scripted runs and background queries.

## Passive background hint

When the application does not choose a background and no query ran, the theme
consults the `COLORFGBG` environment variable as a conservative advisory hint.
Only the exact two- or three-integer form is accepted, and only well-known
final values map: `0` reports a dark background, `7` or `15` report light. Any
other shape - including custom ANSI palette indices whose luminance is not
modelled - is treated as unavailable and falls back to the dark default.
Explicit `ColorPreferences.background` and the bounded background query both
take precedence; `NO_COLOR` still disables colour entirely.

## Colours

Omitting a component palette selects the structural theme's authored
light/dark default for the resolved background. An explicit whole palette in
application configuration replaces that default; an explicit
`ColorThemes.terminalDefault` keeps the old terminal-native behaviour. At
component scope, use `ComponentColors` for whole-palette replacement or
semantic-role overrides. A component override cannot change background
selection, colour detection, query control, I/O or mode. Non-empty `NO_COLOR`
remains a hard restriction at the final output boundary.

## Essential help

The compact primary-action and help route is mandatory for interactive
prompts. `InstructionDisplay.hidden` suppresses optional guidance only; it no
longer hides the essential hint. Screen-reader presentation adds concise
essential text before a prompt. This is an observable behaviour change from
the pre-cutover API.

## Supplied answers and supplied tags

`SuppliedAnswer` and `SuppliedTags` are not part of the supported public API.
Preferred migration is to keep that decision in application logic: call the
theme prompt when a real answer is needed, and apply the application's own
default or pre-validated value when no interaction is intended.

A scripted environment (`TerminalEnvironment.scripted`) is available for
deterministic tests and demonstrations, but it is not behaviourally equivalent
to a supplied answer: scripted bytes still pass through input parsing,
editing, validation, help commands and EOF handling. Values can be rejected or
interpreted as commands, and exhaustion returns `InputEnded` rather than an
instant answer. Do not replace user-facing supplied-answer shortcuts with
scripted I/O and assume identical results.

## Verification and gaps

The external fixture in `fixtures/public_api_fixture` compiles against only
the public barrel and checks every returned handle type. Negative snippets
are analysed in machine format and must produce their expected diagnostic
codes - static factories, direct component constructors, hidden resolver and
fact types, invocation-level I/O, mode or session configuration, parameterless
feedback reconfiguration, `theme.close()` and supplied-answer types are all
rejected. Automated tests cover reusable prompts, EOF, concurrent prompts,
creation-time collection snapshots, live feedback outliving a prompt, the
passive `COLORFGBG` hint, cleanup races and reacquisition at internal seams.
The native Windows fixture has public-API routes (`public-<scenario>`) that
drive real console scenarios through `PlainTheme` with the default native
environment.

These checks do **not** establish native terminal behaviour, real light/dark
visual contrast, or human screen-reader qualification. Windows and macOS
native hints remain behind independent platform validation; Linux has no
established signal. See the release-gate tickets for the outstanding human
evidence.
