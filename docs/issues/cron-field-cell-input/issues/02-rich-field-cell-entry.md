# 02 Rich field-cell entry stage

Status: claimed

**Blocked by:** [01](01-field-cell-model-and-validation.md)

**What to build:** The rich-interaction entry stage of `CronInput`: a row of inline field cells with a focus ring `cell 0 -> ... -> cell N-1 -> trailing action -> cell 0` (N = 5 unix, 7 quartz; trailing action is `Submit` when `preview == null`, `Review` when configured). `Tab` advances, `Shift+Tab` and `Ctrl+B` move backward; entering a cell places the caret at end of its grapheme content. `Enter` from any cell or the trailing stop runs full-draft validation: empty mandatory cells fail naming the field and focus the first empty cell; the first invalid cell gets focus with a field-specific error; quartz `?` violations focus the day-of-month cell. All drafts survive failures. Printable characters (including literal `-` and `+`) insert at the caret; `Left`/`Right`/`Home`/`End`/`Backspace`/`Delete` are grapheme-aware and strictly bounded within the focused cell; `Up`/`Down` are no-ops; ASCII `Space` never inserts or advances and shows a brief notice to use `Tab`. `Tab` out of empty/invalid cells is always allowed while composing. Reuse the shared editor machinery in `lib/src/text_input.dart` (`_edit`, `_Keys`, help/escape plumbing) where it fits; new cell-state code belongs in the part file from ticket 01 or a sibling part file. See the [spec](../spec.md) Implementation Decisions: rich interaction focus ring and keyboard model, validation timing and targeted error recovery.

## Acceptance criteria

- [ ] Rich mode renders and edits per-cell drafts with the specified focus ring and wraparound through the trailing Submit/Review stop.
- [ ] `Enter` from any cell validates the whole draft and either accepts or enters Review per `preview == null`; failures retain all drafts and focus the first offending cell.
- [ ] Intra-cell editing is grapheme-bounded; `Space` is rejected with the Tab-guidance notice; `Up`/`Down` are no-ops; `-`/`+` insert literally.
- [ ] Tests drive `theme.cronInput(...).prompt()` through `TerminalEnvironment.scripted`/`custom` across representative structural themes, asserting observable focus indicators, notices, and `PromptResult<CronExpression>` outcomes — unix 5-cell and quartz 6/7-cell flows, empty-cell rejection, invalid-cell focus recovery.
