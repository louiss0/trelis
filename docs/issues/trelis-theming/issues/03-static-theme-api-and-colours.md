# Specify structural-theme factories and colour configuration
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 02

## Question

What are the exact public structural-theme class names and static component method names/signatures, return types and configuration rules? Map the listed structures to public names without reopening selection. Define the colour-theme object's semantic roles, defaults, per-component override replacement/merge rules, and instruction override API. Decide how direct existing component construction relates to these factories. Preserve type safety and existing behavior. Consult Dart.

## Answer

Approved by bvlou through live decision rounds and explicit confirmation of the concrete interface below. This is an implementation-design decision; no runtime code has been changed.

### Public structural classes

Each is a static factory namespace, not an instance with mutable defaults. Structure declarations remain internal as previously resolved.

| Existing structure ID | Structures-page name | Public class |
|---|---|---|
| rail | Continuous rail | RailTheme |
| minimal | Conversational inline | MinimalTheme |
| ascii | ASCII console | AsciiTheme |
| box | Square enclosure | BoxTheme |
| bracket | Bracketed question | BracketTheme |
| round | Rounded enclosure | RoundTheme |
| form | Fixed-label form | FormTheme |
| chevron | Forward chevron | ChevronTheme |
| plain | Plain text | PlainTheme |
| double | Double enclosure | DoubleTheme |
| branch | Branching rail | BranchTheme |
| line | Underlined question | LineTheme |
| block | Reverse-video label | BlockTheme |
| ledger | Numbered ledger | LedgerTheme |
| colon | Key:value diagnostic | ColonTheme |

The names Signal, Paper, etc. identify colour presets, not additional structural classes. Do not introduce a class for every structure/palette combination.

### Factory interface

All fifteen classes expose the same applicable component factory surface. Names are lower-camel-case forms of the implemented public component names, with the explicit acronym spellings below. Each method returns the existing concrete component type, not a Future, result value or behavior wrapper.

| Static method | Concrete return type |
|---|---|
| textInput | TextInput |
| password | Password |
| confirm | Confirm |
| checkbox | Checkbox |
| toggle | Toggle |
| multiline | Multiline |
| select<T> | Select<T> |
| radio<T> | Radio<T> |
| multiSelect<T> | MultiSelect<T> |
| slider | Slider |
| rangeSlider | RangeSlider |
| treeSelect<T> | TreeSelect<T> |
| timeInput | TimeInput |
| tagInput | TagInput |
| autocomplete | Autocomplete |
| searchSelect<T> | SearchSelect<T> |
| sortableSelect<T> | SortableSelect<T> |
| commandPalette<T> | CommandPalette<T> |
| maskedInput | MaskedInput |
| numberInput | NumberInput |
| portInput | PortInput |
| ipAddressInput | IPAddressInput |
| urlInput | URLInput |
| emailInput | EmailInput |
| colorInput | ColorInput |
| cronInput | CronInput |
| timezoneSelect | TimezoneSelect |
| pathInput | PathInput |
| filePicker | FilePicker |
| directoryPicker | DirectoryPicker |
| keypress | Keypress |
| keyChordInput | KeyChordInput |
| durationInput | DurationInput |
| dateInput | DateInput |
| text | Text |
| progress | Progress |
| spinner | Spinner |
| multiSpinner | MultiSpinner |

Factory parameter lists preserve their corresponding public constructor's positional/named parameters, types, generic parameters, validation contracts and defaults, plus the applicable named presentation parameters below. This is the signature rule, not permission to replace constructor parameters with dynamic maps or a bag of forwarded arguments. The handoff now includes a [source API baseline](../api-baseline.md) and [expanded typed factory signatures](../factory-signatures.md). Implementation must compile and check them against its target source revision; signature notation is not evidence of implemented forwarding.

Interactive components add:

- ColorTheme colors = ColorThemes.terminalDefault
- InstructionDisplay instructions = InstructionDisplay.themeDefault
- List<String> supplementaryHelp = const []

Feedback-only Text, Progress, Spinner and MultiSpinner add colors, not instruction/help parameters. Snapshot supplementary help as immutable configuration; later mutation of a caller's list must not alter a configured component.

The selected structural class configures the returned component internally. Factories do not acquire the terminal, print, start feedback, validate answers, invoke callbacks or start async work. They return fresh configured objects with the existing invocation/lifecycle behavior.

Example (approved interface, not currently implemented):

```dart
final input = RailTheme.textInput(
  'Project name',
  initialValue: 'trelis',
  colors: ColorThemes.signal.copyWith(
    warning: TerminalColor.rgb(255, 190, 80),
  ),
  instructions: InstructionDisplay.compact,
  supplementaryHelp: ['Use the name of your package.'],
);
final result = await input.prompt();
```

### Direct construction and invocation

Existing direct constructors remain supported, gain the same applicable presentation options and default to PlainTheme. They share the same behavior/presentation implementation as factories, not a separate legacy renderer. Plain is a structure, not a forced interaction mode.

Existing mode/source/output configuration remains on prompt(), present() or start() as appropriate; factory methods do not implicitly invoke these. Preserve generic selection T, nullable accepted numeric/colour values, decimal-string slider answers, records and all existing PromptResult outcomes. Feedback objects keep their separate explicit lifecycle; no artificial prompt() is added.

Export the added public interface through the current package entry point. Package/import renaming is outside this effort. Prototype-only components such as StepperForm do not acquire factories merely because an atlas specimen depicts them.

### Instruction options

InstructionDisplay has themeDefault, compact, expanded and hidden.

- themeDefault delegates optional instruction presentation to the chosen structure's per-component/stage defaults.
- compact requests primary actions plus help access.
- expanded requests detailed applicable guidance in the normal presentation; a safe help route remains available.
- hidden hides optional guidance, not help access, state, active-format cues, warnings, validation or required actions/review.

Application instructions override the theme's instruction default, not input behavior. supplementaryHelp adds application-specific explanatory text alongside accurate built-in help; it cannot replace built-in instructions, change controls or remove protected content. Formatting/placement and expanded-help layout follow the later structure contract.

### Colour values and complete palettes

Public names: ColorTheme (immutable complete palette), ColorThemes (named immutable palettes) and TerminalColor (typed terminal colour value). Keep these distinct from ColorInput and ColorValue, which describe user-entered colour answers.

TerminalColor represents terminal-default, indexed colour or opaque RGB. The public constructors/access are TerminalColor.terminalDefault, TerminalColor.indexed(index) and TerminalColor.rgb(red, green, blue). Indexed and RGB channel values are integers in 0..255; reject invalid values with ArgumentError rather than silently clamping. No alpha or arbitrary escape-sequence string form is part of this interface.

ColorTheme custom construction requires every role below as a named TerminalColor value; no missing/inherited role values. Its copyWith accepts changes to any subset of roles and produces another complete immutable palette, retaining unspecified roles. A supplied colors object replaces the default palette wholesale; there is no merge with structure colours and no mutable global theme default.

| Role | Purpose |
|---|---|
| foreground | Ordinary labels and content |
| background | Component-local background |
| muted | Compact hints, secondary text and disabled text |
| accent | Focus and emphasis |
| selectionForeground | Text on selection emphasis |
| selectionBackground | Selection emphasis background |
| success | Success/status role |
| warning | Warning role |
| error | Validation/failure role |
| border | Borders, rules and rails |

Roles do not change semantic state: focused and selected are still separate typed facts. Non-colour indicators remain necessary for focus, selection, disabled state, warnings and errors. Exact placement and combined-state styling are defined in the structure contract.

ColorThemes.terminalDefault is the default for every structural factory and direct constructor. All ten roles use TerminalColor.terminalDefault, so no dark/light terminal surface is assumed. Non-colour structure/markers carry the distinctions. Palette background is component-local; atlas webpage/background colours must not trigger global terminal recolouring.

### Existing named palettes

Expose all 45 existing SPECS palettes from tool/generate_theme_atlas.py as immutable ColorThemes values, separate from structural classes. Lower-camel-case identifiers derive from the existing hyphenated slugs:

signal, paper, mainframe, blueprint, ember, orchid, workbench, tide, ink, arcade, fieldnotes, nordic, punch, ledger, infrared, porcelain, basalt, citrus, lavender, glacier, vinyl, botanical, terminalAmber, slate, solar, deepSpace, moss, copper, midnightMint, typewriter, neonGrid, sandstone, blueHour, matcha, obsidian, clay, polar, forestFloor, ultraviolet, seaGlass, carbon, sakura, terminalGreen, desertDusk, ion.

Preserve existing RGB values. Map atlas text -> foreground, terminal -> background, muted -> muted, accent -> accent and selectionBackground, selected -> selectionForeground, success -> success, error -> error, rule -> border. The atlas has no warning token: use its accent for warning initially, retaining a visible semantic warning indicator; copyWith can override it. Ignore the atlas page colour. No preset is automatically selected by a structural class.

### Follow-through

- [Specify the internal typed presentation and layout vocabulary](06-internal-presentation-vocabulary.md) supplies internal representation without exposing a custom-layout framework.
- [Specify rich and linear presentations for the existing structures](04-rich-and-linear-structure-contracts.md) owns physical layout, semantic role combinations and capability-based colour fallback. Palette RGB/indexed values are requests, not a guarantee that an output can display them.
- [Define theming acceptance evidence and the implementation handoff](05-verification-and-design-handoff.md) must include typed signature inventory/forwarding checks, source-compatible constructor additions, the deliberate PlainTheme/default-palette presentation change, palette mapping and cross-structure coverage.

No additional public API decisions remain implicit in a separate migration fog patch; migration/handoff planning is part of the existing handoff ticket.
