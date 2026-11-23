# 04 Field-cell presentation and geometry

Status: resolved

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** The visual contract for the rich field-cell stage. Replace the verbose prompt-title parenthetical banner with the clean caller `label` plus a minimal inline **active-format cue** `<profile> · <i>/<N> <field-name> (<range-cue>)` that updates with focus (marking quartz year optional) and shows `<profile> · Focus: Submit|Review` with the assembled draft preview on the trailing stop; the cue is protected content visible even when optional instructions are hidden. Field cells render as compact single-row inline containers — never multi-row nested boxes — with symmetric delimiters (`[ value ]` / `[   ]` empty) and a non-colour focus marker (e.g. `[>value<]` ASCII or equivalent glyph per output profile) so focus is never colour-alone. A concise **compact hint** states primary controls and the help route (`Tab/Shift-Tab move; Enter submits|reviews; Ctrl+T help; Esc cancels`). When the cell row exceeds declared column width, wrap *between* whole cells onto continuation lines inside the active structural theme spine; only a single cell wider than the inner line width windows horizontally around the caret. Must compose inside all 15 structural themes and both output profiles, repaint cleanly on idle resize and alongside live feedback in shared sessions without mutating drafts. See the [spec](../spec.md) Implementation Decisions: inline presentation, field-cell rendering, and geometry.

## Acceptance criteria

- [ ] Prompt shows clean label + per-focus active-format cue (protected when instructions hidden) + compact hint within declared geometry.
- [ ] Cells render single-row with symmetric delimiters and explicit non-colour focus markers in both Unicode and ASCII output profiles across representative structural themes (including enclosures and rails).
- [ ] Narrow geometry (e.g. 40 columns) wraps between whole cells; oversized single cells window around the caret; no border overflows declared geometry.
- [ ] Idle resize and shared-session feedback repaint cells/caret/cue without altering drafts.
- [ ] Tests assert emitted display-safe text and geometry through the public seam across themes and profiles.

## Answer

Implemented the field-cell presentation and geometry contract in `CronInput._fieldCells` (`lib/src/cron_input.dart`, ~line 780) on top of the shared `_StructureSpine`.

- **Clean label + active-format cue**: `show()` opens the spine with `title: '$label.'` only — the verbose parenthetical banner is gone. `cue()` emits `<profile> · <i>/<N> <field-name> (<range-cue>[, optional])` for cells and `<profile> · Focus: Submit|Review · draft: <assembled>` on the trailing stop; quartz year carries `optional`. The cue is written as protected body content before `spine.hint`, so it stays visible when `InstructionDisplay.hidden` reduces the hint to `Enter submits|reviews; Ctrl+T opens help.`
- **Compact hint**: `Tab/Shift-Tab move; Enter submits|reviews; Ctrl+T help; Esc cancels.` (submits vs reviews follows preview configuration).
- **Single-row cells with symmetric delimiters**: `cellToken()` renders `[value]`/`[]` unfocused and an explicit non-colour focus marker — `[→value←]` under Unicode glyph sets, `[>value<]` under ASCII — never colour-alone. The trailing action stop renders the same way.
- **Geometry**: `writeCellRow()` tokenizes whole cells and packs them greedily onto continuation rows inside `spine.bodyWriteWidth` (new `_StructureSpine` getter in `lib/src/text_input.dart` ~line 1430 that resolves the effective inner width for enclosure/heading/prefix/plain geometries). Wraps only between cells; when a single cell exceeds the inner width it is windowed horizontally around the caret via `TextDisplayMap` measurement.
- **Resize/shared sessions**: `_watchIdleResize` plus a `_ForwardedResizeObserver` broadcast adapter (~line 429) feed both the stage watcher and each `_edit` call; `stageProfile`/`stageHelpOpen` track live geometry and help visibility so idle resize repaints rows without touching `cells` drafts, and shared-session feedback coexists with the retained editor.

Merge note: resolved conflicts with tickets 03 (paste) and 05/06 (help/review) by keeping this stage's presentation state (`stageProfile`, `stageObserver`, `stageHelpOpen`) while adopting `_fieldCellPaste`/`paste-fields` distribution, `_cellHelp`/`_reviewStopHelp`, and the review-stage flow unchanged.

Tests: new `test/cron_field_cell_presentation_test.dart` (8 tests) asserts emitted display-safe text and geometry through the public seam — label/cue/hint content, review-mode switching, quartz optional year, hidden-instruction cue survival, Unicode/ASCII focus markers, whole-cell wrapping at narrow width, over-wide cell windowing, resize repaint preserving drafts, and composition across all 15 `PromptStructure` values. `test/theme_heading_framing_test.dart` gained a per-case `allowedBareMarkers` exception for cron's legitimate `[ ` cell-delimiter prefix only.

Verification: `dart pub get`, `dart analyze` (no issues), `dart test` — all 5691 tests pass, including theme framing/matrix suites.
