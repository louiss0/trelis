# 03 Field-cell paste handling

Status: resolved

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** Identified-paste behavior for the rich field-cell stage. Single whitespace-free tokens insert at the caret of the focused cell (control-character filtering and the 4096 UTF-16 total-expression limit still apply). Multi-token identified paste with no control/newline characters and no leading/trailing whitespace splits on ASCII space runs: exactly 5 tokens populates all unix cells; 6 or 7 tokens populates quartz cells (6-token paste clears the year cell); focus moves to the last populated cell with caret at end. Individual tokens may be invalid drafts — validation happens on submit. Wrong token count, leading/trailing whitespace, newlines, or exceeding the expression bound rejects the paste with an explanatory notice and leaves all cell drafts and focus unchanged. See the [spec](../spec.md) Implementation Decisions: paste handling in rich interaction.

## Acceptance criteria

- [ ] Single-token paste inserts at the focused cell caret subject to filtering and the length bound.
- [ ] Valid 5/6/7-token pastes distribute across cells with the specified focus/caret outcome; quartz 6-token paste leaves year empty.
- [ ] Malformed, wrong-count, padded, newline-containing, or oversized pastes are rejected with a notice and preserve all drafts and focus.
- [ ] Tests assert observable cell contents, focus, and notices through the public theme/prompt seam.

## Answer

Implemented identified-paste handling for the rich field-cell stage in `CronInput._fieldCells` (`lib/src/cron_input.dart`).

- New `_fieldCellPaste` classifier (delimited "Field-cell paste handling" region, ~line 575) inspects each `\x1b[200~...\x1b[201~` payload before `_edit` sees it:
  - **Single whitespace-free token** (no space/tab/LF/CR): falls through to `_edit`'s own paste path, which filters control characters, inserts at the caret and enforces the cell's grapheme budget. A pre-check rejects the paste with a notice only when the unfiltered payload would push the assembled expression past 4096 UTF-16 code units (covers the astral-character grapheme-vs-code-unit gap).
  - **Multi-token candidate**: rejected with an explanatory notice — leaving all drafts and focus untouched — when the payload contains control/newline characters, has leading/trailing whitespace, splits to the wrong token count (not 5 for unix; not 6 or 7 for quartz), or assembles past the 4096 UTF-16 bound.
  - **Valid multi-token paste**: splits on ASCII space runs, distributes tokens verbatim across all cells (quartz 6-token paste clears `year`), and returns a `paste-fields` action through the cell `_edit` intercept. After `_edit` returns, the staged `cells` list is replaced and focus moves to the last populated cell (unix/quartz-6 → cell index 4/5, quartz-7 → 6) with the caret at its end on the next `_edit` seed. Invalid tokens remain drafts; submit-time validation is unchanged.
- The oversized-paste marker `\x1b[999~` (>4096 UTF-16 payloads) keeps `_edit`'s existing rejection notice.
- Paste on the trailing Submit/Review stop remains swallowed as before.

Tests: new `test/cron_field_cells_paste_test.dart` (9 tests) covers unix/quartz 5/6/7-token distribution, focus/caret outcomes, verbatim invalid-draft deferral to submit validation, single-token caret insertion, control-char filtering, and every rejection rule preserving drafts and focus. Updated `test/cron_field_cells_entry_test.dart`'s stale "reject a multi-token paste" case to use a wrong-count (6-token unix) payload, since a valid 5-token paste now distributes by design.

Deviation: the >4096 assembled-expression rejection for multi-token pastes is defensive/unreachable through `SharedTerminalReader` (payloads over 4096 UTF-16 units arrive as `\x1b[999~`); the check is kept for contract completeness. Single-token bound enforcement is observable via the reader's oversized marker.
