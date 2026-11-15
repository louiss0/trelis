# 18: Deliver PathInput

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver literal native path entry with a stable displayed base and explicit existence/type policy. Relative answers resolve to an absolute path against that base without changing process working directory or applying shell-like expansion, and the resolved candidate is reviewable before acceptance.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] The caller-supplied base or captured current working directory is visible and stable throughout the prompt; accepted paths resolve absolutely against it.
- [x] No implicit tilde, environment-variable, glob, quote-stripping or shell execution occurs; literal spaces and native characters remain data.
- [x] Existence is required by default, while nonexistent-path entry is an explicit caller policy with disclosed target type/meaning.
- [x] Path resolution does not implicitly dereference links or change symlink-sensitive .. meaning; errors preserve draft and context.
- [x] Command-aware quoting preserves slash collisions and Windows rooted/UNC leading backslashes; the returned path makes no later-operation success claim.
