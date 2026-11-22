# Specify rich and linear presentations for the existing structures
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 01, 02, 06

## Question

For each existing structural grammar, what declarative layout rules apply in rich and linear interaction across component families and lifecycle stages? Define placement of labels, state, compact hints, full help, warnings, errors and completion output; define narrow-terminal and capability fallbacks, including semantic colour-role combinations, component-local background handling, RGB/indexed capability degradation and colour-disabled/redirected output policy under the approved colour interface. Linear counterparts must be intentional and sequential/reviewable, not cursor-replay approximations. Apply the resolved internal vocabulary: define safety-area placement for automatically inserted protected content, editable-region caret mapping through width/clipping choices, and event-specific linear blocks rather than repainting full snapshots. Treat atlas palettes and editorial sheet framing separately from runtime layouts. Preserve existing structure choices.

## Answer

Approved by bvlou through live decisions and explicit final confirmation of the fifteen-structure matrix and shared policies below. This preserves the selected structures; it does not select new visual themes or implement rendering.

### Structure matrix

Each declaration consumes the typed content and event vocabulary, not raw controller state. Normal rich views and linear stage/help/review boundaries receive the structure's framing. Smaller linear events retain matching prefixes/indentation/markers without repeatedly dumping a whole frame or current view.

| Public class | Normal grammar and compact hint | Compact linear events and ASCII counterpart |
|---|---|---|
| RailTheme | Connected title/body spine; compact hint closes the rail. | Short continuation blocks use the spine. Replace corners/rail with +, vertical bar and backslash as appropriate. |
| MinimalTheme | Unframed conversational label and body; bare hint below. Preserve the atlas distinction between a simple single-field exchange and a multi-row prompt. | Minimal labelled updates without artificial boxes. ASCII vocabulary where needed. |
| AsciiTheme | Question-mark uppercase heading, indented body, -- hint below. | Same explicit ASCII console vocabulary in event blocks. Always ASCII. |
| BoxTheme | Square enclosure, title at top, body inside; hint outside below. | Compact events use matching indentation/markers; stage/help/review blocks retain the enclosure. ASCII +, - and vertical bar. |
| BracketTheme | Bracketed question heading, indented body and hint; no full enclosing side/bottom frame. | Bracketed event headings or concise continuation rows. |
| RoundTheme | Rounded enclosure with title/body inside; hint outside below. | Compact updates within the same grammar; boundary blocks retain rounded framing. ASCII dot/hyphen/apostrophe/vertical-bar enclosure. |
| FormTheme | Fixed-label heading, rule and left-edged field body; hint below. | Labelled field updates with ASCII rule/edge when needed. Never let atlas padding constants become unbounded alignment requirements. |
| ChevronTheme | Forward chevron heading, indented body, directional hint below. | Directional updates; ASCII > and -> equivalents. |
| PlainTheme | Bare question, indented body and parenthesized compact hint. | Plain labelled updates. Always ASCII; plain does not force linear mode. |
| DoubleTheme | Double-rule enclosure, title/body inside; hint outside below. | Matching compact updates; double-rule boundary blocks. ASCII equals rules and doubled vertical bars. |
| BranchTheme | Branching heading and continuing vertical context; compact hint closes the branch. | Branch-marked continuation blocks; ASCII +-, vertical bar and backslash-hyphen equivalents. |
| LineTheme | Question followed by underline; indented body and hint. | Underlined stage/help/review headings, compact indented updates. ASCII hyphen underline. |
| BlockTheme | Strong label band, reverse-video where supported; indented body and hint below. | Strong labelled updates. Use a textual label band when inverse styling is unavailable, retaining hierarchy without depending on colour. |
| LedgerTheme | Prompt-local stage number, dotted rule and indented body; note: hint. | Numbered task-stage boundaries, compact notes/events. Repaints/help do not advance numbering. |
| ColonTheme | ask: heading, indented body and hint: line. | Typed event prefixes such as state:, warning: and result:, while retaining original semantic content. |

Structural case treatment can follow atlas heading/hint decoration, but must never transform answer data, literal commands, examples, identifiers or stable choice references. Bindings in hints remain truthful. A diagnostic heading's display spelling is not an identity or a new parser command.

### Stage framing, hints, help and safety area

- Label/heading first, then essential active-format/location/context cues and the typed body. Preserve the atlas breathing row before choices where space permits, with the appropriate rail/border continuing through it. Small widths can reduce that space.
- Relevant warnings, validation and required review/action content stay near the body, before the final compact hint. Compose them inside an enclosure/rail when applicable; the hint remains outside Box/Round/Double enclosures as in the atlas.
- The shared compositor inserts omitted protected content in that safety area. It does not restore a verbose optional introduction. Protect help access even when optional instructions are hidden.
- Each component/stage uses the previously resolved primary-action-plus-help hint; themes do not invent controls. Expanded instruction mode supplies applicable detailed guidance using the same grammar, without replacing protected content or changing task semantics.
- Full help uses the selected structure with common section semantics: current-stage actions first, then accepted formats and broader workflow/supplementary help. There are not fifteen separate help behaviors. Use temporary help screens only when supported; otherwise append reviewable help and resume safely.
- Completion, cancellation, interruption and input-end output reflect the actual reported outcome and existing component output contract. Use an explicit outcome marker and approved safe summary where appropriate. Do not stringify Accepted<T>, echo a secret, or manufacture a completed outcome from visual progress. Once a stage ends, do not retain a stale actionable hint as if it were still active.
- Feedback keeps its behavior-owned lifecycle and cadence. Atlas spinner/ETA samples are not permission for layouts to add timers, promises or fabricated progress.

### Linear structure contracts

Full structure is visible on entering a task stage and at deliberate help/review boundaries. Small state changes, validation notices and feedback events use shorter matching blocks. A text/caret event is not a new complete enclosed prompt.

Consume ordered event identities, not snapshot diffs. Rerender/repaint/resize does not append old help, warnings or milestones again. A fresh user help request or a repeated validation occurrence still gets its own event. Repair protected slots per event, not by copying all persistent view content into every event.

Keep stable displayed references, unavailable reasons, command/literal distinctions and sequential reviewability. For outputs that support an editable active line, that active region remains separate from committed history; no cursor operations rewrite earlier transcript exchanges.

### Ledger numbering

Start at 01 for each invocation. Associate numbers with meaningful task-stage identities on first entry; revisiting a stage retains its number. Temporary help and repaint/resize do not allocate numbers. There is no static/global counter shared across prompt objects, constructors or concurrent sessions. This adds display sequencing only, not application/task transitions. Cross-prompt flow numbering and a caller-supplied step interface are deferred beyond this effort.

### Width, height and caret-aware fallback

- Normal frames fit meaningful safe content up to an 80-column total-width cap, further bounded by actual available output width. Total width includes prefixes, padding and borders; do not interpret 80 as an interior width.
- Determine useful stage geometry from safe labels/context/body content without measuring a hidden secret. Keep it stable while typing, so each keystroke does not resize the frame. A stage transition or actual output resize may recompute it.
- The atlas's 42-column widths, 17-character label padding and Python len/ljust calculations are specimen constants, not runtime cell-measurement algorithms.
- Wrap read-only labels, descriptions, notices and help at grapheme boundaries, using display-cell measurement. Preserve all essential content; no silent truncation of warnings, validation or format cues.
- Single-line editable regions use horizontal viewports around the real caret with visible overflow indicators. Do not insert line breaks into answer data. Multiline retains user-entered hard line breaks and uses caret-aware viewports rather than unpredictable frame-induced editing reflow.
- Reduce padding, then stack side-by-side fields in semantic order, then simplify chrome as space demands. Retain the chosen structure's recognizable heading/marker where possible; do not silently replace the class with PlainTheme.
- Viewports may hide offscreen body rows with overflow cues, but keep the active control visible and preserve behavior-owned focus order, source references and paging semantics. Do not add navigation actions just because a renderer clips content.
- Dedicated editable-region anchors survive framing, wrapping of surrounding text, display escaping and clipping. Never substitute a literal atlas caret glyph for the real cursor, split a grapheme, or equate grapheme count with terminal columns.
- Rich rendering needs enough capability/geometry evidence for safe placement. Unknown or unusable measurements must not become invented terminal facts. Exact acquisition, width policy and conservative/explicit-mode handling are specified in the focused follow-up below.

### Glyph and style fallback

PlainTheme and AsciiTheme always use ASCII. Other structures use their atlas vocabulary when the output profile supports it; when glyph support is unknown or unavailable, use the defined ASCII counterpart. Unicode and colour capability are independent of cursor capability and interaction mode.

Shared ASCII state equivalents include explicit focus arrows, checked/unchecked markers, radio/on/off markers, unavailable text and warning/error/outcome labels. Preserve semantic distinctions even when multiple decorative shapes converge under ASCII. Form's atlas includes non-ASCII progress glyphs despite its name; replace those when required rather than assume the whole structure is already ASCII.

Retain structure-specific focus treatment from the atlas, while keeping focus, checked selection, default and unavailability as distinct facts. Focused-row emphasis in a specimen is not proof of accepted/checked selection. Use selectionForeground/selectionBackground as a paired emphasis treatment where declared, accent for focus/emphasis, muted for secondary/disabled content, border for chrome, and warning/error/success for their semantic notices. Styling cannot erase explicit state markers or severity text. Textual hierarchy remains when inverse/bold support is unavailable.

### Colour/output policy

A palette requests colours; it does not force output mode, cursor support or ANSI. Use the best supported RGB/indexed representation or monochrome. Honour NO_COLOR and incapable output. Redirected output contains no ANSI, even if a caller supplies a named RGB palette. Do not read output capability from a different stream merely because stdout happens to be a terminal.

Apply palette background only to component-owned content/frame cells, not the whole terminal, shell or scrollback. Resolve each semantic style with the necessary foreground/background and restore state at owned output boundaries; do not leave palette/inverse styling active for unrelated application output. Unknown colour/glyph support is conservative. Monochrome retains non-colour focus, selection, error and warning indicators.

Exact capability detection/override precedence, indexed conversion and ambiguous-width policies must be explicit in the follow-up; cursor support alone is not colour-depth or glyph proof. The current backend does not already implement these capabilities.

### Evidence and follow-up

Design inputs: tool/generate_theme_atlas.py vocabulary()/prompt() and structures.js descriptive anatomy. Current source evidence: lib/src/text_input.dart has cursor/TERM checks and a local conservative single-line width approximation, but no common Unicode cell-width/layout/capability system; feedback.dart uses different current capability checks and has no colour renderer.

[Specify shared output capabilities and display measurement](07-output-capabilities-and-measurement.md) is now sharp enough to ticket: define how the renderer obtains reliable stream-specific facts, test/scripted overrides, width measurement and colour conversion, and how unknown facts fall back. This is necessary before the verification/handoff decision, not an assertion that the backend already supports the matrix.

No runtime implementation or accessibility qualification was performed.
