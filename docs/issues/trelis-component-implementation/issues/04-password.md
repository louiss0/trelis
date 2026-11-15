# 04: Deliver Password

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a public Password component whose secret value is never treated as a command, quoted text, visible preview, persistent history or diagnostic output. No-echo editing is the default; masking and prefill are explicit options. Ending hidden editing reaches a separate visible action stage in both modes.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] No visible echo is the default, and no secret or length is replayed in labels, help, errors, summaries or logs.
- [x] Explicit masking/prefill options preserve their disclosure risks and require the capable-editor path.
- [x] Hidden editing is literal; Enter reaches visible Submit, Edit, Clear/re-enter, Help and Cancel actions without submitting the edit boundary.
- [x] Submit validates the retained secret; Edit reopens it, Clear starts empty, and neither empty input nor EOF means accept an existing secret.
- [x] Public-session tests use disposable values and prove safe editing/outcomes; actual terminal and NVDA echo behavior remains explicitly verified rather than inferred.
