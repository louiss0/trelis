# 03 Field-cell paste handling

Status: ready-for-agent

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** Identified-paste behavior for the rich field-cell stage. Single whitespace-free tokens insert at the caret of the focused cell (control-character filtering and the 4096 UTF-16 total-expression limit still apply). Multi-token identified paste with no control/newline characters and no leading/trailing whitespace splits on ASCII space runs: exactly 5 tokens populates all unix cells; 6 or 7 tokens populates quartz cells (6-token paste clears the year cell); focus moves to the last populated cell with caret at end. Individual tokens may be invalid drafts — validation happens on submit. Wrong token count, leading/trailing whitespace, newlines, or exceeding the expression bound rejects the paste with an explanatory notice and leaves all cell drafts and focus unchanged. See the [spec](../spec.md) Implementation Decisions: paste handling in rich interaction.

## Acceptance criteria

- [ ] Single-token paste inserts at the focused cell caret subject to filtering and the length bound.
- [ ] Valid 5/6/7-token pastes distribute across cells with the specified focus/caret outcome; quartz 6-token paste leaves year empty.
- [ ] Malformed, wrong-count, padded, newline-containing, or oversized pastes are rejected with a notice and preserve all drafts and focus.
- [ ] Tests assert observable cell contents, focus, and notices through the public theme/prompt seam.
