# Cron field-cell input

Status: ready-for-agent
Labels: ready-for-agent

## Problem Statement

Entering a cron schedule in a single free-form text line forces users to mentally track space-separated positions, remember whether they are currently editing `day-of-month`, `month`, or `day-of-week`, and recall profile-specific rules (such as five-field Unix versus six- or seven-field Quartz and Quartz's required `?` day selector) without spatial structure. At the same time, dumping the entire cron grammar, character-limit boilerplate, and preview caveats into the main prompt banner clutters every structural theme while still failing to tell the user which specific cron field they are editing right now.

Users want to fill in a cron expression left-to-right the way they write cron by hand, stepping deliberately from one **cron field** to the next with `Tab` across visible **field cells**, with minimal inline clutter and rich stage-aware **component help** carrying the detailed field syntax and dialect rules on demand.

## Solution

Replace `CronInput`'s **rich interaction** free-form line editor with a row of profile-determined, inline **field cells** arranged left-to-right in standard written cron order:

- **Unix profile (`CronProfile.unix`)**: 5 required **field cells** — `minute`, `hour`, `day-of-month`, `month`, `day-of-week`.
- **Quartz profile (`CronProfile.quartz`)**: 6 required **field cells** plus an optional 7th `year` **field cell** — `second`, `minute`, `hour`, `day-of-month`, `month`, `day-of-week`, `[year]`.

In **rich interaction**, users edit one **field cell** at a time using standard cron field tokens for the active profile (`*`, integers, ranges, lists, steps, month/weekday names, and Quartz special tokens), press `Tab` to move rightward across the **field cells** (and `Shift+Tab` or `Ctrl+B` to move backward), and press `Enter` from any cell (or from the trailing stage action) to validate and accept or enter **cron matching preview** review. Leaving Quartz's 7th `year` **field cell** blank cleanly omits the 7th field and produces a 6-field `CronExpression` without trailing spaces or silent `*` insertion.

Inline presentation stays minimal: the prompt label, the row of **field cells**, a concise **active-format cue** naming the active profile and the focused **cron field**'s position, unit, and base range (marking Quartz `year` as optional), and a **compact hint** advertising primary controls and the route to help. Pressing `F1` (or `/help` in **linear interaction**) opens **component help** that leads with the currently focused **cron field**'s accepted tokens and rules before summarizing the full field map, cross-field day rules, length limit, and optional **cron matching preview** behavior. **Linear interaction** preserves single-line space-separated expression entry with full task equivalence.

## User Stories

1. As a CLI end user scheduling a Unix job in **rich interaction**, I want to see 5 side-by-side **field cells** ordered `minute`, `hour`, `day-of-month`, `month`, `day-of-week`, so that I can fill in a cron schedule left-to-right in the exact order cron expressions are written.
2. As a CLI end user scheduling a Quartz job in **rich interaction**, I want to see 7 side-by-side **field cells** ordered `second`, `minute`, `hour`, `day-of-month`, `month`, `day-of-week`, `year`, so that both required sub-minute scheduling and optional year constraints are spatially visible and reachable.
3. As a CLI end user scheduling a standard 6-field Quartz job, I want to leave the 7th `year` **field cell** blank and press `Enter` right after filling `day-of-week` (or after tabbing past `year`), so that omitting the optional year requires no extra typing and produces a clean 6-field `CronExpression` with no trailing space or injected `*`.
4. As a CLI end user scheduling a year-bounded Quartz job, I want to `Tab` into the 7th `year` **field cell** and enter a year expression (`1970-2199`, `*`, range, list, or step), so that my accepted `CronExpression` preserves all 7 fields.
5. As a CLI end user, I want `Tab` to advance focus rightward from the current **field cell** to the next **field cell**, then to the trailing stage action (`Submit`, or `Review` when preview is configured), and wrap back to the first **field cell**, so that I can navigate the entire prompt predictably from the keyboard.
6. As a CLI end user, I want `Shift+Tab` and `Ctrl+B` to move focus leftward across the trailing action and **field cells** (wrapping from the first cell to the trailing action), so that I can go back to correct an earlier **cron field** without restarting.
7. As a CLI end user, I want pressing `Enter` while focused on any **field cell** to trigger full-expression validation and immediately submit (or enter `Review` when preview is configured), so that I do not have to `Tab` through remaining cells once my schedule is complete.
8. As a CLI end user, I want pressing `Space` inside a **field cell** to be rejected without inserting whitespace or skipping cells, accompanied by a brief hint to use `Tab` to move to the next field, so that muscle memory from typing raw space-separated cron strings does not corrupt a cell or silently jump past fields.
9. As a CLI end user, I want `CronInput` with an empty `initialValue` to start with all **field cells** empty and require every mandatory cell to be explicitly filled before acceptance, so that Trelis never silently invents `*` or `?` values I did not choose.
10. As a CLI end user editing a Unix **field cell**, I want to enter numbers, `*`, `a-b` ranges, `a,b` lists, `/n` steps, `JAN-DEC` month names, `SUN-SAT` weekday names, and `0` or `7` for Sunday in their respective cells, so that every supported Cronie-style expression can be authored cell by cell.
11. As a CLI end user editing a Quartz **field cell**, I want to enter `?`, `L`, `LW`, `L-n`, `L-nW`, `nW`, weekday `L`, and `d#n` nth-weekday tokens in the day cells where Quartz permits them, so that full Quartz day semantics work inside **field cells**.
12. As a CLI end user typing `-` or `+` inside a **field cell**, I want those characters treated as literal text edits rather than numeric step shortcuts, so that I can type ranges like `1-5`, `MON-FRI`, and `L-2W` naturally.
13. As a CLI end user pressing `Left`, `Right`, `Home`, `End`, `Backspace`, or `Delete` inside a focused **field cell**, I want grapheme-aware caret movement and deletion to stay strictly bounded within that single cell, so that editing one cell never accidentally erases or crosses into an adjacent cell.
14. As a CLI end user pressing `Up` or `Down` inside a **field cell**, I want those keys to be no-ops, so that navigation does not behave inconsistently between plain integers and stepped or named cron tokens.
15. As a CLI end user, I want to `Tab` freely out of an empty, partial, or syntactically invalid **field cell** while composing my **draft answer**, so that I can fill fields in any order (such as setting Quartz's `?` in `day-of-week` before editing `day-of-month`) without getting trapped.
16. As a CLI end user who submits an incomplete or invalid **draft answer**, I want validation to retain every cell's exact text, explain which **cron field** or day-combination rule failed, and move focus directly to the first offending **field cell** (or the first day cell when Quartz's `?` exclusivity rule is violated), so that I can fix the problem immediately in place.
17. As a CLI end user, I want my exact token spelling and letter case in every **field cell** (such as `05`, `mon-fri`, or an explicit 7th `*` in Quartz) preserved verbatim when cells are joined with single ASCII spaces into `CronExpression.expression`, so that my input is never silently normalized or rewritten.
18. As a CLI end user who copies a full space-separated cron expression from documentation or a crontab and pastes it into **rich interaction**, I want an identified paste with 5 tokens in `unix` or 6/7 tokens in `quartz` to populate the corresponding **field cells** (leaving Quartz cell 7 blank on a 6-token paste), so that pasting complete schedules remains effortless.
19. As a CLI end user who pastes a single whitespace-free token (such as `*/15` or `MON-FRI`), I want it inserted at the caret inside the currently focused **field cell**, so that single-field paste works like ordinary text editing.
20. As a CLI end user who pastes a multi-token string with the wrong number of fields for the active profile or exceeding the 4096 UTF-16 code-unit expression bound, I want the paste rejected with a clear validation notice while leaving all existing **field cell** drafts untouched, so that a bad paste never scrambles my work.
21. As a CLI end user looking at the prompt in **rich interaction**, I want a minimal inline **active-format cue** that updates with focus (for example `unix · 1/5 minute (0-59)` or `quartz · 7/7 year (1970-2199, optional)`) alongside a concise **compact hint**, so that I always know which **cron field** I am in without verbose inline walls of text.
22. As a CLI end user who presses `F1` in **rich interaction**, I want **component help** to open leading with the currently focused **cron field** (its unit, range, and allowed tokens/names/special characters) or active review stage, followed by the full field order map, day-combination rules, the 4096 UTF-16 code-unit limit, **cron matching preview** context, and any **supplementary help**, without mutating my **draft answer**, focused cell, or caret.
23. As a CLI end user viewing transient **component help** in **rich interaction**, I want pressing `Escape` to dismiss help first and return me to the exact **field cell** and caret position I was editing, so that reading help never cancels my prompt by mistake.
24. As a CLI end user with `CronPreviewConfig` configured, I want valid **field cells** to transition into the `Review` **interaction stage** offering `Edit`, `Preview`, and `Submit`, where `Edit` returns focus to cell 1 with all cell drafts preserved, `Preview` computes the bounded **cron matching preview**, and `Submit` accepts the `CronExpression`.
25. As a CLI end user running a slow **cron matching preview**, I want `Escape` in **rich interaction** (or `/cancel` in **linear interaction**) to cancel only the in-flight preview and return to `Review` with my retained **draft answer**, while `Ctrl+C` performs immediate **prompt interruption** from any stage.
26. As a CLI end user in the **field cells** or in `Review` (when no transient help or preview calculation is active), I want `Escape` in **rich interaction** and `/cancel` in **linear interaction** to perform **prompt cancellation** (`Cancelled<CronExpression>`), so that backing out of the prompt behaves consistently across Trelis.
27. As a CLI end user on a narrow terminal (such as 40 columns) or typing wide list tokens inside **field cells**, I want cells to size to their content on a single line per cell and wrap whole **field cells** onto continuation rows when needed (horizontally windowing inside a single cell only if that cell alone exceeds row width), so that no **field cell** is torn mid-token and no border overflows declared **output profile** geometry.
28. As a CLI end user across all 15 **structural themes** and both Unicode and ASCII **output profiles**, I want **field cells** rendered as compact single-row inline containers rather than multi-row nested boxes, so that enclosing themes like `BoxTheme`, `RoundTheme`, and `DoubleTheme` stay clean and fit tight row budgets.
29. As a CLI end user in **linear interaction** (or screen-reader presentation), I want to enter the full space-separated cron expression on one line with `/help`, `/cancel`, and (when preview is configured) `/preview`, `/edit`, and `/submit`, with concise essential context presented before the prompt in screen-reader mode and invalid drafts retained for correction, so that non-cursor and assistive workflows achieve the exact same task outcome without tedious 5-to-7-step sequential questioning.
30. As a CLI developer using a Trelis **structural theme** instance, I want `theme.cronInput(...)` to validate a non-empty `initialValue` against the selected `CronProfile` at construction time (throwing `ArgumentError` if malformed, out of range, padded with leading/trailing spaces, or wrong field count) and split valid defaults into the initial **field cells** on every reusable `.prompt()` run, so that bad defaults fail fast and repeated runs always start cleanly from `initialValue`.
31. As a CLI developer running a **shared session** with live **feedback components** or terminal resize events while `cronInput` is active, I want background feedback updates and idle geometry changes to repaint the **field cells**, focused cell, caret, and **active-format cue** cleanly inside the updated geometry without accepting or altering the **draft answer**.

## Implementation Decisions

- **In-place replacement on the existing component contract**: Replace `CronInput`'s **rich interaction** entry stage behind the existing `StructuralTheme.cronInput` method and internal `ThemeFormattedPrompt.cron` / `CronInput` delegation. No new public classes, enums, or parameters are added; `PromptResult<CronExpression>`, `CronProfile`, `CronPreviewConfig`, `CronPreview`, and `CronPreviewStatus` keep their public signatures and semantics.
- **Profile-determined field-cell schemas in canonical cron order**:
  - `CronProfile.unix` defines 5 required **field cells**:
    1. `minute` (`0-59`)
    2. `hour` (`0-23`)
    3. `day-of-month` (`1-31`)
    4. `month` (`1-12`, `JAN-DEC`)
    5. `day-of-week` (`0-7`, `SUN-SAT`, where `0` and `7` both denote Sunday)
  - `CronProfile.quartz` defines 6 required **field cells** followed by 1 optional 7th **field cell**:
    1. `second` (`0-59`)
    2. `minute` (`0-59`)
    3. `hour` (`0-23`)
    4. `day-of-month` (`1-31` or `?`, plus `L`, `LW`, `L-n`, `L-nW`, `nW`)
    5. `month` (`1-12`, `JAN-DEC`)
    6. `day-of-week` (`1-7`, `SUN-SAT`, or `?`, plus `L`, `dL`, `d#n`)
    7. `year` (`1970-2199`, optional)
- **Initial cell state and constructor `initialValue` validation**:
  - When `initialValue` is empty (`''`), every **field cell** initializes to `''` and focus starts on cell 0. Empty mandatory cells are never silently coerced to `*` or `?`.
  - When `initialValue` is non-empty, construction validates it against the selected `CronProfile` (including the 4096 UTF-16 code-unit limit, absence of leading/trailing whitespace, field count, and profile field/day rules). Any non-empty `initialValue` that fails profile validation throws `ArgumentError` at construction, matching `TimeInput` and `DurationInput`.
  - A valid non-empty `initialValue` splits on ASCII space runs into the initial **field cells** (5 cells for `unix`; for `quartz`, 6 fields populate cells 0..5 with cell 6 set to `''`, and 7 fields populate cells 0..6). Each invocation of a reusable `ThemePrompt<CronExpression>` resets the cells to this configured `initialValue`.
- **Expression assembly and verbatim token preservation**:
  - For `unix`, the candidate expression joins cells `0..4` with single ASCII spaces (`' '`).
  - For `quartz`, if cell 6 (`year`) is empty (`''`), the candidate expression joins cells `0..5` with single ASCII spaces (emitting a 6-field expression with no trailing space and no injected `*`). If cell 6 is non-empty, it joins cells `0..6` with single ASCII spaces (emitting a 7-field expression).
  - User spelling and case within each cell are preserved verbatim without normalization. Total assembled expression length remains bounded to `4096` UTF-16 code units; edits or pastes that would push the assembled draft (including single spaces between active fields) past `4096` UTF-16 code units are rejected without partial insertion.
- **Rich interaction focus ring and keyboard model**:
  - Focus positions in the entry **interaction stage** form an ordered ring: `cell 0 -> ... -> cell (N-1) -> trailing action -> cell 0`, where `N` is `5` (`unix`) or `7` (`quartz`), and the trailing action is `Submit` when `preview == null` or `Review` when `preview != null`.
  - `Tab` advances forward one stop in the ring; `Shift+Tab` and `Ctrl+B` move backward one stop. Entering a **field cell** via `Tab` / `Shift+Tab` / `Ctrl+B` places the caret at the end of that cell's grapheme content.
  - `Enter` (`\r` or `\n`) from *any* **field cell** or from the trailing `Submit`/`Review` stop runs full-draft validation and, if valid, either returns `Accepted<CronExpression>` (`preview == null`) or transitions to the `Review` **interaction stage** (`preview != null`).
  - Typing ASCII `Space` (`' '`) inside a **field cell** never inserts whitespace and never advances focus; it preserves the draft and caret and displays a protected notice instructing the user to press `Tab` to move to the next field.
  - Printable non-control characters (including `-`, `+`, `*`, `/`, `,`, `?`, `#`, digits, and letters) insert at the cell caret. `Left`, `Right`, `Home`, `End`, `Backspace`, and `Delete` operate on grapheme clusters strictly within the focused cell and do not cross cell boundaries. `Up` and `Down` are no-ops on **field cells**.
- **Paste handling in rich interaction**:
  - Single-token paste (containing no whitespace or line breaks) inserts at the caret in the currently focused **field cell**, subject to control-character filtering and the 4096 UTF-16 total expression limit.
  - Multi-token identified paste (trimmed of neither leading nor trailing tokens unless split cleanly: specifically, containing no control/newline characters and containing internal ASCII spaces without leading/trailing whitespace) splits on single/multiple ASCII spaces:
    - If the token count matches the profile (`5` for `unix`; `6` or `7` for `quartz`) and fits within `4096` UTF-16 code units, all cells are populated (`quartz` 6-token paste clears cell 6 `year` to `''`) and focus moves to the last populated cell (`cell 4` for `unix`, `cell 5` for 6-token `quartz`, `cell 6` for 7-token `quartz`) with the caret at its end. Individual tokens may still be invalid drafts and are validated on submit.
    - Otherwise (wrong token count, leading/trailing whitespace, newlines, or exceeding `4096` UTF-16 code units), the paste is rejected with an explanatory notice and existing cell drafts and focus remain unchanged.
- **Validation timing and targeted error recovery**:
  - Tabbing between cells never blocks on empty or invalid cell content; each cell holds an independent local draft string.
  - On `Enter` or activating `Submit`/`Review`, cells are validated in index order:
    1. Any empty mandatory cell (`0..4` in `unix`; `0..5` in `quartz`) fails validation with a message naming the missing **cron field**, focusing that first empty cell.
    2. Each populated cell (including cell 6 `year` in `quartz` when non-empty) is validated against its **cron field** grammar and range; the first invalid cell receives focus (caret at end) with a field-specific validation error.
    3. For `quartz`, after individual field syntax passes, the day exclusivity rule (exactly one of `day-of-month` cell 3 and `day-of-week` cell 5 must be `?`) is checked; if violated, focus moves to cell 3 (`day-of-month`) with a message stating that Quartz requires `?` in either `day-of-month` or `day-of-week` (not both and not neither).
  - All cell drafts remain intact across validation failures.
- **Inline presentation, field-cell rendering, and geometry**:
  - Replace the verbose prompt-title parenthetical banner with the clean caller `label`, paired with a minimal inline **active-format cue** (which is **protected content** and remains visible even when optional instructions are hidden).
  - When focused on a **field cell**, the **active-format cue** states `<profile> · <i>/<N> <field-name> (<range-cue>)` (for example `unix · 1/5 minute (0-59)` or `quartz · 7/7 year (1970-2199, optional)`). When focused on the trailing action, it states `<profile> · Focus: Submit` (or `Focus: Review`) alongside the assembled draft preview.
  - **Field cells** render on single logical content rows (never multi-row nested ASCII/box art) so they compose cleanly inside all 15 **structural themes** (enclosures, rails, branches, headings, forms, ledgers, blocks, plain, and ASCII). Unfocused cells use symmetric inline cell delimiters (`[ value ]` or `[   ]` when empty) and the focused cell uses an explicit non-colour focus marker in addition to theme focus/accent styling (for example `[>value<]` in ASCII or `[→value]` / distinct focused cell framing consistent with the output profile's glyph repertoire) so focus is never conveyed by colour alone.
  - When the row of **field cells** exceeds declared column width, layout wraps *between* whole **field cells** onto continuation lines inside the active **structural theme** spine, never splitting a cell's delimiters and token across lines unless a single cell's content alone exceeds the available inner line width, in which case that cell windows horizontally around the caret.
  - The **compact hint** stays within declared geometry and states primary controls and the help route (`Tab/Shift-Tab move; Enter submits; F1 help; Esc cancels`, adapting `Enter submits` to `Enter reviews` when `preview != null`).
- **Stage-led component help (`F1` / `/help`)**:
  - Pressing `F1` in **rich interaction** (or `/help` in **linear interaction**) presents **component help** without mutating any cell draft, caret offset, or focused cell/action (`HelpStateSnapshot` invariance).
  - Help leads with the current **interaction stage**:
    - When focused on a **field cell**, it opens with that specific **cron field**'s name, position, numeric bounds, and accepted tokens/names/special characters (including whether cell 7 `year` is optional in `quartz`).
    - When focused on the trailing `Submit`/`Review` stop or inside the `Review` stage, it opens with that stage's controls and actions.
  - In the same block, help includes the profile's full ordered field map, day-combination semantics (`unix` OR matching when both day fields are restricted, including stepped wildcards, versus `quartz` mandatory single `?`), the 4096 UTF-16 code-unit limit, the **cron matching preview** status/bounds/non-execution disclaimer (or disclosure that preview is not configured), and any caller **supplementary help**.
- **Preview stage, cancellation layers, and linear interaction**:
  - When `preview != null`, valid submission enters the existing `Review` **interaction stage** (`Edit`, `Preview`, `Submit` in **rich interaction** via `Tab`/`Shift+Tab` + `Enter`; `/edit`, `/preview`, `/submit` in **linear interaction**). Choosing `Edit` returns to **field cell** 0 with all 5 or 7 cell drafts retained.
  - Layered `Escape` in **rich interaction**: dismisses open transient **component help** first; cancels an in-progress **cron matching preview** calculation second (returning to `Review`); otherwise cancels the prompt (`Cancelled<CronExpression>`) from either the **field cells** or `Review`. `Ctrl+C` returns `Interrupted<CronExpression>` from every layer. Input stream exhaustion returns `InputEnded<CronExpression>`.
  - **Linear interaction** (and screen-reader mode, which resolves to linear presentation with concise essential text before the prompt) continues to accept the complete space-separated cron expression on a single **command-aware entry** line (`/help`, `/cancel`, backslash command quoting, identified paste as **literal entry**, and `/preview`, `/edit`, `/submit` during review), validating against the exact same 5-field `unix` and 6-or-7-field `quartz` rules and retaining invalid drafts for correction.

## Testing Decisions

- **What makes a good test**: Tests must assert observable behavior at the public boundary — emitted display-safe text, **field cell** focus indicators, **active-format cues**, **compact hints**, **component help** text and state invariance, geometry wrapping, terminal lease restoration, and returned `PromptResult<CronExpression>` / `CronPreview` values — rather than reaching into private cell buffers, internal focus indices, or helper functions.
- **Single testing seam**: Drive tests through the top-level public package surface using the 15 `StructuralTheme` classes bound to `TerminalEnvironment.scripted` or `TerminalEnvironment.custom` (with `OutputProfile`, `InteractionPreferences`, `ColorPreferences`, `NativeHintObservations`, and `TerminalIoResizeObserver` where relevant), invoking `theme.cronInput(...).prompt()` and `CronExpression.preview(...)`. No new testing seams are introduced.
- **Behaviors to cover across tests**:
  - Unix 5-cell left-to-right `Tab` entry, `Shift+Tab` / `Ctrl+B` reverse navigation, ring wraparound through trailing `Submit`/`Review`, and `Enter` direct submission from middle cells.
  - Quartz 7-cell entry covering both omitted 7th `year` cell (producing a 6-field `CronExpression` and matching across years in preview) and populated 7th `year` cell (producing a 7-field `CronExpression` bounded to `1970-2199`).
  - Empty initial cells rejecting blank mandatory cells on submit without silent `*` or `?` substitution, focusing the first missing cell while preserving populated cells.
  - Constructor `ArgumentError` on invalid non-empty `initialValue`, and clean per-invocation reset to valid 5-, 6-, and 7-field `initialValue` strings across repeated `.prompt()` calls on the same `ThemePrompt<CronExpression>`.
  - Intra-cell grapheme editing (`Left`, `Right`, `Home`, `End`, `Backspace`, `Delete` staying within cell bounds), literal `-` and `+` typing, `Up`/`Down` no-op behavior, and `Space` rejection with the Tab guidance hint.
  - Single-token paste into the focused cell, valid 5/6/7-token space-separated paste distributing across cells, and malformed/wrong-count/oversized paste rejection preserving existing cell drafts.
  - Per-field range/token errors and Quartz `?` day-exclusivity errors retaining all cell drafts and moving focus to the first offending cell.
  - Minimal inline **active-format cue** updates per focused cell, **protected content** retention when optional instructions are hidden, and `F1` / `/help` stage-led **component help** (including **supplementary help** and snapshot invariance of cell drafts, focus, and caret, plus `Escape` dismissing transient help without cancelling).
  - Optional `CronPreviewConfig` `Review` workflow (`Edit` round-tripping back to populated cells, `Preview` reporting bounded instants, `Escape` / `/cancel` stopping an active preview back to `Review`, second cancellation ending the prompt, and `Ctrl+C` interrupting).
  - Narrow-geometry whole-cell wrapping (such as 40-column profiles across enclosing and rail **structural themes**), ASCII vs. Unicode non-colour focus indicators, live resize repaint invariance, **shared session** live **feedback component** coexistence, and **linear interaction** / screen-reader presentation parity.
  - Updating existing compatibility and structural-theme acceptance matrix suites whose scripted rich-mode inputs assumed single-line cron entry so they drive the new **field cell** `Tab` workflow cleanly.
- **Prior art in the codebase**: Follow the behavioral patterns established by the public theme-instance suite, the themed formatted-component suite, segmented rich-versus-linear tests for `DateInput` and `TimeInput`, the cron profile/preview/workflow conformance suites, and the 15-theme framing and acceptance matrix suites.

## Out of Scope

- Reordering **cron fields** into big-endian (`year`-to-`second`) or reversed cron order.
- Auto-filling blank mandatory cells with `*` or `?`, normalizing case or leading zeros, or extracting cron expressions from crontab command lines, environment directives, or `@daily`-style macros.
- Step-incrementing or decrementing cell values with `Up`/`Down` or `+`/`-`.
- Changing **linear interaction** from single-line expression entry to multi-step sequential per-field prompts.
- Adding a second cron prompt component or expanding the public API surface with new configuration flags.
- Registering, scheduling, or executing jobs, or claiming daemon scheduler emulation beyond bounded civil-time **cron matching previews**.
- Human-operated native terminal and assistive-technology release qualification gates, which remain tracked under their dedicated platform evidence workflows.

## Further Notes

- Domain glossary terms **Cron field** (avoiding *cron number*) and **Field cell** (avoiding *box*, which conflicts with `BoxTheme` and enclosing **structural themes**) have been recorded in the root domain glossary alongside **Active-format cue**, **Compact hint**, **Component help**, **Cron matching preview**, **Rich interaction**, and **Linear interaction**.
- Keeping Quartz's 7th `year` **field cell** optional preserves full compatibility with existing 6-field and 7-field `CronProfile.quartz` expressions, so no architectural deviation ADR is required.
