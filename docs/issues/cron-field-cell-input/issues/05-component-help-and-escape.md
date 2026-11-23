# 05 Stage-led component help and entry-stage escape layers

Status: resolved

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** `Ctrl+T` **component help** for the rich field-cell stage and the entry-stage escape layering. Help opens without mutating any cell draft, caret, or focused cell/action (`HelpStateSnapshot` invariance), leads with the currently focused **cron field**'s name, position, bounds, and accepted tokens/names/special characters (flagging quartz year optional) — or the trailing Submit/Review stage's controls when that stop is focused — then includes the profile's full ordered field map, day-combination semantics (unix OR-matching incl. stepped wildcards vs quartz mandatory single `?`), the 4096 UTF-16 limit, preview status/bounds/non-execution disclaimer or not-configured disclosure, and caller supplementary help. Escape layering in rich interaction: dismiss transient help first (returning to the exact cell and caret), then cancel the prompt (`Cancelled<CronExpression>`) from cells or Review; `Ctrl+C` interrupts from every layer; input exhaustion returns `InputEnded`. See the [spec](../spec.md) Implementation Decisions: stage-led component help, preview stage/cancellation layers (entry-stage portion here).

## Acceptance criteria

- [x] `Ctrl+T` opens stage-led help focused on the current cell or trailing action; cell drafts, caret, and focus are invariant across open/dismiss.
- [x] Help content covers focused-field detail first, then full field map, day rules, length limit, preview disclosure, and supplementary help.
- [x] `Escape` dismisses help before the focused cell/caret; a second `Escape` cancels the prompt; `Ctrl+C` interrupts; EOF returns `InputEnded`.
- [x] Linear `/help` parity for the same content where the linear path supports it.
- [x] Tests assert help text, snapshot invariance, and layered outcomes through the public seam.

## Answer

Stage-led component help and entry-stage escape layering completed in `lib/src/cron_input.dart` on top of the ticket-02 `_fieldCells` stage; no public API changed and cell editing, paste, presentation and the Review-stage internals are untouched.

- `_cellHelp` now leads with the focused field cell's name, `i/N` position, bounds (`rangeCue`) and per-cell accepted tokens via the new `_cellAccepted` (month `JAN-DEC`, unix weekday `SUN-SAT`/`0`-`7` Sunday, Quartz `?`/`L`/`LW`/`L-n`/`L-nW`/`nW`/`dL`/`d#n` specials, optional `year` blank-omission note), followed by the dialect shape, the new ordered `Field order:` map (`_fieldMap`), the new `Day rule` note (`_dayRules`), the 4096 UTF-16 limit, the stage-appropriate preview disclosure (`_stagePreviewNote`) and caller `supplementaryHelp` appended by `_withSupplementary`.
- New `_reviewStopHelp` describes the trailing Review stop's controls (validate + open review stage); `_submitStopHelp`, `_reviewHelp`, `_entryHelp` and `_submitHelp` carry the same field map, day rules and supplementary help, giving linear `/help` parity in entry and review.
- Escape layering needed no new machinery: `_edit` already swallows every key except `\x1b`/`\x03`/EOF while its transient help is open, so the first `Escape` dismisses help with `chars`/`pos` untouched (cell drafts live outside the editor), the second reaches the cell/stop editor and returns `Cancelled<CronExpression>`; `Ctrl+C` interrupts from inside help and EOF returns `InputEnded`. The Review stage keeps its own layering (preview-cancel via `onKey`, then prompt cancel).
- `test/cron_field_cells_help_test.dart` (9 tests): focused-cell help content + caret/draft/focus invariance (`'5'` + Left + help + `'1'` yields `15`, not `51`), Quartz year optional flag, Submit- and Review-stop help, Review-stage help, Escape-then-cancel layering, Ctrl+C inside help, EOF inside help, and linear `/help` parity with and without a configured preview. `test/cron_workflow_migration_test.dart`'s rich-help assertion was updated to the new stage-led lead (`Help: Editing the minute field cell 1/5`).
- Verified: `dart pub get`, `dart analyze` clean, `dart format` clean, full `dart test` green (5666 tests). Integration tip `754488c` was already merged; tickets 03/04 had not landed, so no conflicts.
