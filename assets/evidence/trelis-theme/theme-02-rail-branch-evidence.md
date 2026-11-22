# Ticket 02 evidence: RailTheme and BranchTheme

**Status:** resolved
**Source revision:** `HEAD` on `ticket/theme-02-rail-branch`
**Integration base:** `523ebfcd2ca99697017f5db28a311637bfd45791`
**Environment:** Windows 11, Dart SDK 3.13.2 (stable), local worktree
`C:\Users\bvlou\projects\prompty-theme-02`

## What was built

- `lib/src/prompt_structure.dart`: the public `PromptStructure` vocabulary (all
  15 structures), `StructureGlyphs`, `glyphsFor`, `usesStructurePrefix`,
  `structurePrefixCells` and `frameStructureLines`. Only the rail and branch
  glyphs are implemented; every other structure reserves its name and frames
  nothing yet.
- `lib/src/themes/rail_theme.dart`: `RailTheme` with all 38 typed static
  factories, each forwarding `structure: PromptStructure.rail`.
- `lib/src/themes/branch_theme.dart`: `BranchTheme` with all 38 typed static
  factories, each forwarding `structure: PromptStructure.branch`.
- `PromptStructure structure` added to all 34 interactive component
  constructors and the four feedback components, with delegating wrappers
  (`ColorInput`, `CronInput`, `DurationInput`, `EmailInput`,
  `IPAddressInput`, `NumberInput`, `PortInput`, `CommandPalette`,
  `TimezoneSelect`, `Slider`/`RangeSlider`) forwarding it to the component that
  actually renders.
- `_StructureSpine` (internal, `lib/src/text_input.dart`): one writer for a
  stage's read-only lines. It wraps to the width left by the prefix, opens the
  spine on the first block, continues it on later blocks, and closes it when the
  block carries the compact hint. `reset()` lets a repaint open the structure
  again instead of dumping a second frame.
- Structure framing wired into every applicable interactive render path, rich
  and linear: `TextInput`, `Password`, `Confirm`/`Checkbox`/`Toggle`,
  `Multiline`, `Select`/`Radio`, `MultiSelect`, `Slider`, `RangeSlider`,
  `TreeSelect`, `SortableSelect`, `TimeInput`, `TagInput`, `Autocomplete`,
  `SearchSelect`, `MaskedInput`, `NumberInput`, `PortInput`,
  `IPAddressInput`, `URLInput`, `EmailInput`, `ColorInput`, `CronInput`,
  `DurationInput`, `DateInput`, `PathInput`, `FilePicker`,
  `DirectoryPicker`, `Keypress`, `KeyChordInput`, and the four feedback
  components.
- The shared editor (`_edit`) keeps the structure's continuation prefix on the
  rich editable row, on the linear submit echo, on editor notices, on help and
  on the sequential `Current text:`/`Cursor position:` reports, so smaller
  linear events stay inside the spine instead of repainting a whole frame.
- `MaskedInput`'s notice sink (`_WrappedNotices`) frames whole notices with
  `hint()` for the compact hint and plain `writeln` for later events, so its
  many editor messages share one grammar without per-call plumbing.
- `lib/prompty.dart` exports `src/prompt_structure.dart`,
  `src/themes/rail_theme.dart` and `src/themes/branch_theme.dart`.
- `tool/generate_theme_factories.py` regenerates the rail and branch namespaces
  from `plain_theme.dart`, forwarding the structure for the interactive and
  feedback factories alike.
- Tests:
  - `test/rail_theme_factories_test.dart` (17 tests)
  - `test/branch_theme_factories_test.dart` (17 tests)
  - `test/rail_theme_acceptance_matrix_test.dart` (rich/linear matrix)
  - `test/branch_theme_acceptance_matrix_test.dart` (rich/linear matrix)
  - `test/theme_structure_rendering_test.dart` (8 tests)
  - `test/theme_structure_framing_test.dart` (135 tests)
  - `test/public_compatibility_inventory_test.dart` updated for the new exports.

## Verification results

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format .` then `dart format --output=none --set-exit-if-changed .` | 0 changed |
| Static analysis | `dart analyze` | No issues found |
| Full suite | `dart test` | +1405, all passed |
| Theme verification | `dart test test/theme_structure_framing_test.dart test/theme_structure_rendering_test.dart test/rail_theme_acceptance_matrix_test.dart test/branch_theme_acceptance_matrix_test.dart test/rail_theme_factories_test.dart test/branch_theme_factories_test.dart` | +328, all passed |
| Issue-tracker boundary | `dart run tool/check_issue_tracker.dart` | No legacy tracker |

## Structure grammar check

`test/theme_structure_framing_test.dart` runs 31 component cases through
`RailTheme` and `BranchTheme` in both modes and asserts:

- the output opens with the theme's start glyph (`│ `, `├ `, `| ` or `+-`),
- an unframed (`PlainTheme`) component produces none of those glyphs,
- a linear run against an `automatic` glyph profile falls back to ASCII and
  never emits `│` or `├`,
- a rich run against a `unicode` profile never emits the ASCII vocabulary,
- the compact hint closes the structural line (`\ ` / `\-`) for 15
  representative components including every editor family,
- the prefix is part of the measured width: a 28-column rail and a 30-column
  branch keep every framed line inside the declared columns,
- the rich editable row keeps the rail prefix and the real caret anchors
  (`ESC[s`/`ESC[u`), so framing never becomes a physical cursor,
- stage help, a protected validation message (with its `\u{0007}` spelling) and
  the accepted summary all stay framed and truthful,
- an overridden palette styles the framed rail while the accepted value is
  unchanged, and feedback keeps its own lifecycle while gaining a prefix.

## Representative visible output

Normal width, `RailTheme.textInput`, linear, 72 columns, `automatic` glyphs:

```text
| Deployment target (Optional).
| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; En
| ter submits. /help opens help. Escape cancels; Ctrl+C interrupts.
| Exact /help and /cancel are commands. Quote a command with a backslash
| ; double a leading backslash to enter one. Identified paste is literal
\ .
```

Normal width, `BranchTheme.textInput`, linear, 72 columns:

```text
+-Deployment target (Optional).
| Left/Right move; Home/End go to boundaries; Backspace/Delete erase; En
| ter submits. /help opens help. Escape cancels; Ctrl+C interrupts.
| Exact /help and /cancel are commands. Quote a command with a backslash
| ; double a leading backslash to enter one. Identified paste is literal
\-.
```

Narrow width, `RailTheme.select`, linear, 56 columns, including deliberate
linear event blocks:

```text
| Region Select: 2 choices.
| Page 1 of 1.
| 1. Europe [focused]
| 2. United States
| Enter a stable choice number to accept it. /next, /pre
| vious, /help and /cancel are exact commands. Quote com
| mands with a backslash; double a leading backslash. Id
\ entified paste is literal.
| Current text: 
\ Cursor position: 0 of 0 graphemes.
| Current text: 2
\ Cursor position: 1 of 1 graphemes.
| Accepted: United States.
```

Narrow rich terminal, `BranchTheme.textInput`, Unicode glyphs, 40 columns:

```text
├ Deployment target (Optional).
│ Left/Right move; Home/End go to bounda
│ ries; Backspace/Delete erase; Enter su
│ bmits. Ctrl+T opens help. Escape cance
└ ls; Ctrl+C interrupts.
```

## Limitations and remaining work

- Only `rail` and `branch` have glyphs. The other 13 `PromptStructure` values
  are declared vocabulary with no rendering yet; their tickets
  (`03`–`06`) own that work, and `frameStructureLines` is a no-op for them.
- A single-line stage that both opens and closes the spine keeps the start
  glyph rather than the closing glyph, so components that write one compact
  line (for example the tree stage hint) show `│ hint` instead of `└ hint`.
  Multi-line stages, which is where the hint closure matters, do close.
- The structural prefix is added after display escaping and before styling, so
  the safety renderer's spelling of protected content is unchanged; the ASCII
  and Unicode fallbacks are chosen from the declared `OutputProfile` only.
- No native-terminal visual qualification was performed: every result here is
  scripted output, not a screenshot or a manual terminal review.
- Cross-structure palette and NO_COLOR behaviour is inherited from the ticket
  01 colour layer and is not re-qualified per structure here.

## Conclusion

The RailTheme and BranchTheme factory namespaces, the structural vocabulary and
its shared framing helpers, the 38-factory surface for both classes, and the
rail/branch grammar across every applicable interactive and feedback render
path are implemented, verified by 1405 passing tests, and committed. The ticket
is **resolved** and the worktree is ready for merger.
