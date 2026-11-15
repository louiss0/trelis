# 11: Deliver SearchSelect

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver searchable single-choice selection with explicit query/result focus and predictable default matching. A person can edit a query, inspect results, choose one enabled result, handle no matches and return to a still-valid prior/default result without free-form submission or accidental acceptance.

**Blocked by:**
- [06: Deliver Autocomplete](06-autocomplete.md)
- [09: Deliver Select and Radio](09-select-radio.md)

**Status:** resolved

- [x] Default matching is case-insensitive substring filtering over advertised searchable labels, preserving original option order; other matching policies are explicit.
- [x] Enter in query moves to results without submitting; arrows can enter results; Enter in results submits only the focused enabled choice.
- [x] Tab traverses query/results/actions and typing to filter returns to query editing, not letter-jump selection.
- [x] Result entry/resumption restores still-valid default/matching or prior focus, otherwise first enabled result, without silently replacing removed candidates.
- [x] Linear query then numbered result/action flow includes /search, review/paging, no-match recovery and stable identity; stale async results cannot select an answer.
