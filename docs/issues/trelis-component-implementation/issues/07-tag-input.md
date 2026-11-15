# 07: Deliver TagInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver ordered tag collection with exactly application-configured kebab-case or snake-case normalization. Users can preview and correct canonical tags, reject canonical duplicates, and deliberately add, edit, remove and finish the collection without accidental draft loss.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Only kebab-case (default) and snake-case are available; the application chooses before entry and the active style is explained.
- [x] Word-aware Unicode-preserving normalization handles whitespace/separators/camel/acronym boundaries, preserves combining meaning and rejects unsupported punctuation rather than silently deleting it.
- [x] Canonical validation, length limits and exact duplicate comparison operate on normalized values; rejected drafts remain correctable.
- [x] Rich canonical preview does not rewrite the draft; linear addition reports canonical output with review/edit/remove actions.
- [x] Enter adds a valid nonempty draft, Finish or /done submits, unadded drafts require explicit resolution, and rich Backspace focuses before explicit deletion.
