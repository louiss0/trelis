# 03: Deliver TextInput and the shared public prompt-session foundation

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver TextInput end to end as the first public component class: construct it without touching the terminal, invoke its prompt method, and complete an answer in rich or linear mode. Establish the shared session foundation for mode precedence, streams, outcomes, commands, paste, grapheme editing, defaults, validation and lifecycle, exercised through a shared scripted public-behavior test seam rather than private component hooks.

**Blocked by:**
- [02: Prove editable defaults and shared Windows + NVDA interaction](02-editable-default-nvda-probe.md)

**Status:** resolved

- [x] Construction holds validated configuration without acquiring input/rendering; invocation starts a fresh non-concurrent session and returns explicit accepted/cancelled/interrupted/input-ended/unavailable outcomes.
- [x] Mode precedence, explicit rich failure, stderr default, explicit input-source policy and stable redirected output follow the shared contract.
- [x] TextInput preserves entered text, distinguishes required/optional empty input, supports actual editable defaults and retains drafts with actionable validation errors.
- [x] Grapheme editing, line boundaries, oversized insertion, command quoting, literal data/paste provenance and partial EOF work through the public interaction boundary.
- [x] Shared deterministic tests cover rich and linear tasks, lifecycle, mode/capability failures and repeated sessions without inspecting private state.
