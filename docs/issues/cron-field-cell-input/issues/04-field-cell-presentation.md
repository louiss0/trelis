# 04 Field-cell presentation and geometry

Status: ready-for-agent

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** The visual contract for the rich field-cell stage. Replace the verbose prompt-title parenthetical banner with the clean caller `label` plus a minimal inline **active-format cue** `<profile> · <i>/<N> <field-name> (<range-cue>)` that updates with focus (marking quartz year optional) and shows `<profile> · Focus: Submit|Review` with the assembled draft preview on the trailing stop; the cue is protected content visible even when optional instructions are hidden. Field cells render as compact single-row inline containers — never multi-row nested boxes — with symmetric delimiters (`[ value ]` / `[   ]` empty) and a non-colour focus marker (e.g. `[>value<]` ASCII or equivalent glyph per output profile) so focus is never colour-alone. A concise **compact hint** states primary controls and the help route (`Tab/Shift-Tab move; Enter submits|reviews; Ctrl+T help; Esc cancels`). When the cell row exceeds declared column width, wrap *between* whole cells onto continuation lines inside the active structural theme spine; only a single cell wider than the inner line width windows horizontally around the caret. Must compose inside all 15 structural themes and both output profiles, repaint cleanly on idle resize and alongside live feedback in shared sessions without mutating drafts. See the [spec](../spec.md) Implementation Decisions: inline presentation, field-cell rendering, and geometry.

## Acceptance criteria

- [ ] Prompt shows clean label + per-focus active-format cue (protected when instructions hidden) + compact hint within declared geometry.
- [ ] Cells render single-row with symmetric delimiters and explicit non-colour focus markers in both Unicode and ASCII output profiles across representative structural themes (including enclosures and rails).
- [ ] Narrow geometry (e.g. 40 columns) wraps between whole cells; oversized single cells window around the caret; no border overflows declared geometry.
- [ ] Idle resize and shared-session feedback repaint cells/caret/cue without altering drafts.
- [ ] Tests assert emitted display-safe text and geometry through the public seam across themes and profiles.
