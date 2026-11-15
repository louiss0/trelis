# 30: Deliver MultiSpinner

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver feedback-only concurrent-task presentation with stable named task identities and order, meaningful rich/linear updates and a complete final group summary. Concurrent intermediate output is bounded across the group without hiding individual failures or treating mixed results as blanket success.

**Blocked by:**
- [29: Deliver Text, Progress, and Spinner](29-text-progress-spinner.md)

**Status:** resolved

- [x] Each task retains stable identity/order and explicit waiting/running/terminal state; every linear update identifies its task.
- [x] Intermediate progress/phase updates coalesce across the whole group into at most one batch per configurable five-second default window.
- [x] Start, final outcomes and failures do not wait for the intermediate timer; genuine final outcomes remain reviewable even if frequent.
- [x] Every individual failure and mixed result is retained in the final group summary; disposal/100 percent never becomes blanket success.
- [x] Late updates after task finalization cannot alter retained output, and no component acquires input or owns operation cancellation.
