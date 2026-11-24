# Keybind gesture-cell input

Status: ready-for-agent
Labels: ready-for-agent

## Problem Statement

`CommandPalette` is a thin `SearchSelect` wrapper that searches command
identities. A real command palette wants a full-screen TUI surface; inside a
prompt library it duplicates `SearchSelect` and earns no place on the theme
API. `KeyChordInput` builds a gesture sequence through a command-style review
list (`c` capture, `d` declare, `r` remove, `x` clear) that forces users to
memorize action letters and gives no spatial view of the gesture being
composed — the same problem free-form cron entry had before field cells.

Users want to compose one keybinding as an ordered row of **symbol cells**
the way they already compose cron expressions: visible cells laid out left
to right in declaration order, `Tab` between cells, and each cell edited in
place. A gesture declaration is `Ctrl+Shift+B`: modifier symbols first, one
key symbol last. Unlike cron's free-text cells, each cell is **select-based**
and its catalog depends on its position: modifier cells cycle through
`Ctrl`/`Alt`/`Shift`/`Meta`; the trailing key cell cycles through the whole
keyboard-symbol vocabulary.

## Solution

Remove `CommandPalette` from the library, the theme surfaces, examples and
tests. Replace `KeyChordInput` with **`Keybind`**, a cell-row editor modeled
on `CronInput`'s field-cell stage that composes **one gesture declaration**:

- The prompt opens with **two cells**: one modifier cell and one key cell.
  `+` adds a cell after the focused cell; `-` removes the focused cell.
  Removal refuses below two cells; there is no upper bound.
- A cell's role is positional: **every cell except the last is a modifier
  cell** cycling `Ctrl`, `Alt`, `Shift`, `Meta`; **the last cell is the key
  cell** cycling the full symbol vocabulary (letters, digits, `F1`–`F12`,
  named keys). A modifier is required — every binding starts with at least
  one modifier cell.
- `Enter` validates and accepts the ordered **token list** as
  `List<String>` (`['Ctrl', 'Shift', 'B']`); duplicate modifiers are
  rejected because the declaration grammar allows each at most once.
- `Keybind.joined(...)` is the flagged variant whose prompt returns the
  joined declaration **string** (`'Ctrl+Shift+B'`) instead of the token
  array.

Inline presentation stays minimal: the prompt label, the framed cell row,
an **active-format cue** naming the focused cell's position and value, and a
**compact hint** advertising movement, cell add/remove, submission and help.
**Linear interaction** keeps task equivalence with a single-line
`Ctrl+Shift+B`-style declaration entry validated against the same rules.

## User Stories

1. As a CLI end user in **rich interaction**, I want to see my keybinding as
   a row of framed **symbol cells** in declaration order, starting with one
   modifier cell and one key cell, so that the gesture I'm composing is
   spatially visible.
2. As a CLI end user, I want the first cell — and every cell before the
   last — to cycle only through `Ctrl`, `Alt`, `Shift` and `Meta`, so that
   the modifier prefix is the only choice a modifier cell offers.
3. As a CLI end user, I want the last cell to cycle through every keyboard
   symbol — letters, digits, `F1`–`F12`, `Enter`, `Tab`, `Escape`, `Space`,
   `Backspace`, `Delete`, `Insert`, `Home`, `End`, `PageUp`, `PageDown`,
   `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight` — so that the key half
   of the binding can be anything bindable.
4. As a CLI end user on an unset cell, I want `Up` or `Down` to land on the
   first catalog entry with wraparound cycling, so that filling a new cell
   takes one keystroke.
5. As a CLI end user, I want `Tab` to move focus rightward across the cells
   and wrap to the first cell, and `Shift+Tab`/`Ctrl+B` to move leftward,
   so that navigation matches `CronInput`'s field cells.
6. As a CLI end user, I want `Left` and `Right` to move focus between cells
   as well, so that cell travel works on arrows when there is no caret to
   move.
7. As a CLI end user, I want `+` to insert a new unset cell right after the
   focused cell and move focus into it, so that a longer modifier prefix
   grows where I'm working.
8. As a CLI end user, I want `-` to remove the focused cell, so that I can
   shrink the prefix; when only two cells remain I want a notice instead of
   silent failure.
9. As a CLI end user, when adding or removing cells shifts a set cell into
   a different role — key cell becoming a modifier cell or vice versa — I
   want that cell's selection cleared when it is not in the new role's
   catalog, so that no illegal token survives a structural edit.
10. As a CLI end user, I want `Enter` from any cell to submit the whole
    gesture, so that I don't have to tab to a trailing action once the
    binding is complete.
11. As a CLI end user submitting with unset cells or a repeated modifier, I
    want validation to keep every selection and move focus to the offending
    cell with an explanatory notice, so that I can fix it in place.
12. As a CLI end user, I want a minimal **active-format cue** like
    `cell 2/3 · Shift · modifier` plus a **compact hint**, so that I always
    know where I am without verbose inline text.
13. As a CLI end user pressing `Ctrl+T`, I want **component help** that
    leads with the focused cell's position, role and catalog rules,
    followed by the full control list and any supplementary help, without
    mutating the gesture or focus.
14. As a CLI end user viewing help, I want `Escape` to dismiss help first
    and return me to the exact cell I was editing; a second `Escape`
    performs **prompt cancellation**.
15. As a CLI end user pasting `Ctrl+Shift+B` (or comma-separated
    `Ctrl,Shift,B`), I want the tokens to populate cells in order — the
    cell count growing or shrinking to match, never below two — when the
    tokens form a valid gesture, so that known bindings paste in one step.
16. As a CLI end user pasting a single modifier or key symbol, I want it to
    set the focused cell when the symbol is in that cell's catalog;
    anything else is rejected with a notice and the draft is untouched.
17. As a CLI end user on a narrow terminal, I want cells to size to their
    content and wrap whole cells onto continuation rows, so that no cell is
    torn mid-symbol.
18. As a CLI end user in **linear interaction** or screen-reader mode, I
    want to type the gesture as a `Ctrl+Shift+B`-style declaration on one
    line, validated against the same token rules with `/help` and
    `/cancel`, so that non-cursor workflows achieve the same task outcome.
19. As a CLI developer, I want `theme.keybind(label, ...)` to return
    `ThemePrompt<List<String>>` and `theme.joinedKeybind(label, ...)` to
    return `ThemePrompt<String>` (the `'Ctrl+Shift+B'` form), so that the
    answer shape is chosen at construction.
20. As a CLI developer, I want `modifiers` and `symbols` catalog
    parameters with defaults — the four modifiers and the full key
    vocabulary — validated at construction (non-empty, unique, members of
    the declaration grammar), and `initialValue` token validation the same
    way, throwing `ArgumentError` on bad configuration.
21. As a CLI developer running a shared session with live feedback or
    resize events, I want the cell row, focus marker, cue and hint to
    repaint cleanly inside the updated geometry without losing the draft.

## Implementation Decisions

- **`CommandPalette` removal**: delete `lib/src/command_palette.dart` and its
  `part` declaration, `SearchSelect._palette`, `ThemeSearchPrompt.commandPalette`
  and `ThemeSearchComponent.commandPalette`, `commandPalette` on the public
  theme API and on every structural theme factory, the fifteen example
  programs, the dedicated tests, and the fixture/tooling references.
  Historical issue-tracker documents stay unchanged.
- **`KeyChordInput` renamed and re-interacted**: the class becomes
  `Keybind<T>` in `lib/src/key_capture.dart`; `theme.keyChordInput` becomes
  `theme.keybind`. `Keypress`, `KeyGesture`, `KeyModifier` and
  `KeyGestureProvenance` keep their public signatures; `Keypress` remains
  the observation path. `Keybind` has no `requireObservation` parameter —
  the select surface never observes physical input.
- **Answer shape**: `Keybind(label, ...)` resolves `PromptResult<List<String>>`
  — the ordered cell tokens. `Keybind.joined(label, ...)` is the flagged
  variant resolving `PromptResult<String>` — the tokens joined with `+` into
  one declaration string. The generic `Keybind<T>` keeps both answer shapes
  statically typed; the theme API mirrors it with `theme.keybind` →
  `ThemePrompt<List<String>>` and `theme.joinedKeybind` →
  `ThemePrompt<String>`.
- **Catalog contract**: `modifiers` defaults to `['Ctrl', 'Alt', 'Shift',
  'Meta']` and every entry must be one of those four names; `symbols`
  defaults to the full declaration key vocabulary (letters both cases,
  digits, `F1`–`F12`, named keys) and every entry must parse under the
  declaration grammar without colliding with a modifier name. Empty
  catalogs, invalid entries and duplicates throw `ArgumentError` at
  construction.
- **`initialValue`**: `List<String>` of tokens, validated at construction —
  every token but the last must name a modifier, the last must name a
  symbol, and modifiers may not repeat. The initial cell count is
  `max(2, initialValue.length)`; a shorter `initialValue` leaves the
  remaining cells unset (a lone modifier seeds `[modifier, unset]`).
  Reusable `.prompt()` runs reset to this state.
- **Cell model**: each cell is unset or holds a token string. A cell's
  catalog is determined by position: every cell but the last uses
  `modifiers`; the last uses `symbols`. When a structural edit moves a set
  cell into the other role, the selection is cleared unless it is a member
  of the new role's catalog. `Up`/`Down` steps the cell through its catalog
  with wraparound, settling an unset cell on the first entry. Cells are
  never text edited — there is no caret, and printable keys other than the
  `+`/`-` controls are no-ops.
- **Focus ring and keyboard model** (rich interaction): `Tab` advances and
  `Shift+Tab`/`Ctrl+B` retreat across cells, wrapping at both ends; `Left`
  and `Right` do the same. `+` (and `=`) inserts an unset cell after the
  focused cell and focuses it; `-` (and `_`) removes the focused cell,
  refusing below two cells with a notice. `Enter` validates — every cell
  set, no repeated modifier — and accepts `Accepted(List<String>)` (or the
  joined `String`) in cell order, focusing the first offending cell with a
  notice on failure. `Ctrl+T` opens stage help; `Escape` dismisses help
  first then cancels; `Ctrl+C` interrupts; EOF ends input.
- **Presentation**: cells render as compact single-row framed tokens on the
  same wrapped-row layout as cron's field cells (square or round delimiters
  via the `cellFrame` parameter), never torn mid-token; the active-format
  cue reports `cell i/N`, the focused value or `unset`, and the role name
  (`modifier`/`key`); the compact hint advertises
  move/change/add/remove/submit/help.
- **Paste**: identified paste containing a token sequence separated by `+`
  or `,` (no whitespace or control characters, token count `>= 2`, forming
  a valid gesture) resizes the cells to the token count and populates them
  in order, focusing the last cell; a single catalog symbol sets the
  focused cell; everything else is rejected with a notice and the draft is
  untouched.
- **Linear interaction**: single-line `Ctrl+Shift+B`-style declaration
  entry. Submit validates the tokens: `>= 2`, all but the last modifiers
  (unique, catalog members), the last a catalog symbol; invalid drafts are
  retained with a corrective notice. `/help` and `/cancel` keep their
  shared meaning. `SuppliedAnswer` follows the same grammar — `Ctrl+Shift+B`
  or comma-separated `Ctrl,Shift,B` — and anything else is `Unavailable`.
- **Acceptance**: the ordered cell tokens are returned as `Accepted` —
  `List<String>` for `Keybind`, `String` (`tokens.join('+')`) for
  `Keybind.joined`. `Cancelled`, `Interrupted`, `InputEnded` and
  `Unavailable` keep their shared semantics.
