# 05 Stage-led component help and entry-stage escape layers

Status: claimed

**Blocked by:** [02](02-rich-field-cell-entry.md)

**What to build:** `Ctrl+T` **component help** for the rich field-cell stage and the entry-stage escape layering. Help opens without mutating any cell draft, caret, or focused cell/action (`HelpStateSnapshot` invariance), leads with the currently focused **cron field**'s name, position, bounds, and accepted tokens/names/special characters (flagging quartz year optional) — or the trailing Submit/Review stage's controls when that stop is focused — then includes the profile's full ordered field map, day-combination semantics (unix OR-matching incl. stepped wildcards vs quartz mandatory single `?`), the 4096 UTF-16 limit, preview status/bounds/non-execution disclaimer or not-configured disclosure, and caller supplementary help. Escape layering in rich interaction: dismiss transient help first (returning to the exact cell and caret), then cancel the prompt (`Cancelled<CronExpression>`) from cells or Review; `Ctrl+C` interrupts from every layer; input exhaustion returns `InputEnded`. See the [spec](../spec.md) Implementation Decisions: stage-led component help, preview stage/cancellation layers (entry-stage portion here).

## Acceptance criteria

- [ ] `Ctrl+T` opens stage-led help focused on the current cell or trailing action; cell drafts, caret, and focus are invariant across open/dismiss.
- [ ] Help content covers focused-field detail first, then full field map, day rules, length limit, preview disclosure, and supplementary help.
- [ ] `Escape` dismisses help before the focused cell/caret; a second `Escape` cancels the prompt; `Ctrl+C` interrupts; EOF returns `InputEnded`.
- [ ] Linear `/help` parity for the same content where the linear path supports it.
- [ ] Tests assert help text, snapshot invariance, and layered outcomes through the public seam.
