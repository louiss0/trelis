# Trelis migration guidance

**Status:** published with ticket 07
**Source revision:** the commit that records this document on
`ticket/theme-07-theme-matrix`, over the test revision
`ee54b97`
**Integration base:** `2feac1ba216d3066fcd61dcaa48ac01328e657cf`
(`merge(themes): integrate line and block structural themes`)
**Ticket:** [07: Verify the full theme matrix and publish migration guidance](../../../docs/issues/trelis-theme-integration/issues/07-theme-matrix-and-migration.md)

This is the guidance for consumers moving to the Trelis theme work. It
describes what changes, what does not, and what remains unqualified. It is not
an implementation and does not itself claim a test pass; the evidence for that
is in [the theme matrix evidence](theme-07-matrix-evidence.md).

## 1. Name, package and imports

The project is called **Trelis**. The package name, the library name and every
import path are unchanged:

```dart
import 'package:prompty/prompty.dart';
```

No package, library, class or import renaming is part of this effort. Code that
imported `package:prompty/prompty.dart` before the fifteen themes existed keeps
importing exactly that.

## 2. Direct constructors keep the reference presentation

A direct constructor still renders the presentation it always rendered:

```dart
final name = TextInput('Name');           // reference presentation
final themed = TextInput('Name', structure: PromptStructure.box);
final viaTheme = BoxTheme.textInput('Name'); // the same configuration
```

- `structure:` defaults to `PromptStructure.plain` on every interactive
  component and every feedback class, so an unchanged call site renders
  unchanged output.
- `colors:` defaults to `ColorThemes.terminalDefault`, which forces no colour
  and no surface (see section 4).
- `instructions:` defaults to `InstructionDisplay.themeDefault`, which keeps the
  reference presentation's expanded opening guidance.
- Theme factories configure objects. They never invoke `prompt`, `present` or
  `start`, and they take no output sink, so choosing a theme cannot perform
  terminal I/O. Session, profile, source, mode, resize observer and transcript
  configuration all stay on the invocation:

```dart
final result = await BoxTheme.textInput('Name').prompt(
  source: ScriptedInput(keys, output),
  mode: PromptMode.rich,
);
```

- Feedback factories (`text`, `progress`, `spinner`, `multiSpinner`) take only
  the label/content, the timing and `colors:`. They deliberately do not acquire
  instruction or help parameters.

## 3. Compact help and warning visibility

- `InstructionDisplay.themeDefault` and `.expanded` show the reference,
  expanded guidance; `.compact` keeps a single marked hint line under the stage;
  `.hidden` removes the optional guidance. Every value keeps essential prompt
  context, a discoverable route to full help (`Ctrl+T` in rich output, `/help`
  in linear output) and protected content.
- A structure that encloses or decorates its heading puts the guidance in the
  compact hint below the stage instead of in one labelled block. Placement is
  part of the grammar; the words are not rewritten.
- Warnings are printed with the explicit `Warning:` label and through the
  palette's `warning` role. Every named preset maps `warning` to its `accent`
  (the documented fallback), so a warning is never quieter than the accent, and
  the label means warning visibility never depends on colour.
- Structure decoration is textual chrome — rail and branch spines, enclosure
  rules, headings, underlines and label bands — so the hierarchy survives a
  monochrome terminal, `NO_COLOR` and redirected logs. Inverse styling is added
  only where the output declares style support; it is never the only reason a
  band can be seen.

## 4. Palettes and defaults

- `ColorThemes.terminalDefault` remains the constructor default. All ten roles
  are terminal-native: it forces no dark or light surface and styles nothing.
- 45 named presets are immutable `ColorTheme` values. Each one maps the
  specification's five role pairs plus the surface roles from the source atlas:
  `foreground` is the atlas text colour, `background` the declared terminal
  surface (**never** the atlas page colour, which is artwork), `selectionBackground`
  the accent, `selectionForeground` the atlas selected-foreground, `success`,
  `error`, `border` the atlas rule, and `warning` the accent fallback. Ten roles
  are always present and never left terminal-native in a preset.
- `copyWith` returns a new palette and never mutates a preset. A whole custom
  palette is a complete `ColorTheme` with all ten roles.
- There is no global colour state and no dark/light mode switch: `colors:` on a
  component affects that component only, and neighbouring components keep their
  own palette.
- Colour conversion follows the resolved depth: RGB where the output declares
  RGB, the nearest indexed value otherwise, ANSI-16 where only that is
  available, and no colour at all when the depth is `none`. A depth that cannot
  express a colour emits the default foreground/background request instead of a
  wrong approximation.

## 5. Profiles and sessions

- `OutputProfile` describes output only. It never acquires input and owns no
  terminal state. Resolution order is: invocation profile, then the source
  profile, then the legacy `supportsRich` cursor hint, otherwise conservative
  defaults (no colour, ASCII glyphs, no styles, no alternate screen, automatic
  geometry).
- A non-empty `NO_COLOR` and a redirected stream are hard restrictions applied
  before an invocation reaches it. A profile declaration cannot force colour or
  rich output a real stream cannot support; the restriction wins.
- `OutputProfile.copyWith` changes one fact and preserves the rest, with an
  explicit automatic sentinel per fact.
- Feedback can attach to a `TerminalSession`, which inherits the session's
  output and presentation configuration. Passing `output`, `mode`,
  `userPreference`, `applicationPreference` or `supportsRich` to session feedback
  is rejected rather than silently ignored.

## 6. Explicit synthetic geometry for scripted rich output

Rich output is entered only when the resolved profile declares a supported
cursor **and** a complete geometry (`OutputProfile.supportsRichInteraction`).
Scripted and automated runs must therefore declare geometry explicitly:

```dart
final profile = OutputProfile(
  cursor: CapabilitySupport.supported,          // rich is possible
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 72, rows: 20), // required
  glyphs: GlyphSet.unicode,
);
final input = ScriptedInput(Stream.value('Ada\r'), buffer,
    outputProfile: profile);
await TextInput('Name', structure: PromptStructure.block)
    .prompt(source: input, mode: PromptMode.rich);
```

- `OutputGeometry.automatic()` means "no usable dimensions": an invocation that
  needs a width stays linear instead of guessing one.
- A rich hint is not proof of anything except cursor support. Colour, glyphs,
  styles, alternate screen and geometry each resolve independently, so a
  scripted run that wants a themed rich stage must state all four.
- Feedback started directly takes `mode:` and `supportsRich:` for the same
  reason; feedback attached to a session inherits the session's facts.

## 7. What does not change

- **Accepted value types.** Every component keeps the payload of its
  `Accepted<T>` unchanged: `String`, `bool`, `T` for a choice list, the typed
  editor values (`MaskedValue`, `DurationValue`, `CronExpression`, colour
  values, path and URL spellings, and so on). A structure changes presentation
  only.
- **Outcomes stay distinct.** `Accepted`, `Cancelled`, `Interrupted`,
  `InputEnded` and `Unavailable` remain separate result types with their own
  reasons. Escape is still cancellation, `Ctrl+C` still interruption, end of
  input still `InputEnded`, and a refused or unavailable answer is still
  `Unavailable`; no structure rewrites one outcome as another.
- **Acceptance, focus, references.** No structure infers an accepted selection
  from emphasis, changes a stable choice reference, moves focus, or changes what
  counts as valid input.
- **Protected content.** A masked secret is never echoed; a control character in
  a message keeps its spelled form (`\u{0007}`); validation and review text stay
  inside the stage instead of being swallowed by an open frame.

## 8. Out of scope and unqualified

- **Accessibility qualification.** Whole-library accessibility remains
  unqualified. No NVDA, screen-reader, human-checkpoint or
  actual-physical-keyboard claim follows from the theme work, from automated
  tests, from snapshots or from injected GUI input.
- **Universal width correctness.** Display width is verified against the
  declared 80-cell chrome cap and each component's own width behaviour, and
  ambiguous-width treatment is a declaration (`AmbiguousWidth`) rather than a
  guarantee about every terminal and font. Universal terminal/font width
  correctness is unqualified, as is East Asian ambiguous-width agreement across
  arbitrary fonts.
- **Packaging.** No package or import renaming.
- **Platforms.** Windows observations are scripted and agent-visible only; no
  native-terminal visual qualification was performed. Linux and macOS remain
  CI-only (see the evidence document for what the workflow covers).
