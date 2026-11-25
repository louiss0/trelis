# 06 Deterministic timing, resize, platform, and locale test evidence

Status: claimed

**Blocked by:** none

**What to build:** Remove consequential fixed sleeps from the identified asynchronous prompt, colour-input, feedback batching, resize, and native PowerShell interaction tests. Use the existing FeedbackClock seam for MultiSpinner batching, controlled resize notification streams where possible, provider completion/event-queue drainage/observable output conditions with bounded deadlines elsewhere, and bounded waits for prompt/help/caret states in native scripts. Keep only a small polling smoke test that awaits the observable reflow condition. Convert bare platform conditional returns into explicit test-platform declarations or reasoned skips. Provision or assert CI locale prerequisites so missing numeric/date fixtures fail as prerequisite diagnostics rather than silently passing. Preserve exact terminal byte assertions where those bytes are the external contract. See the [spec](../spec.md), especially “Test determinism and environment honesty”.

## Acceptance criteria

- [ ] Identified fixed sleeps that merely hope asynchronous work finished are replaced by deterministic state, clock, notification, readiness, or bounded observable conditions.
- [ ] MultiSpinner batching tests use the existing FeedbackClock seam rather than real milliseconds.
- [ ] Resize behavior uses controlled notifications where possible; the remaining polling smoke test bounded-waits for actual reflow.
- [ ] Native PowerShell interactions wait for prompt, help, dismissal, or restored-caret state rather than fixed post-key delays.
- [ ] Platform-only tests declare platform/reasoned skips, and locale prerequisites are provisioned or fail explicitly in CI.
- [ ] Focused tests, analyzer, and relevant broader test suites pass.

## Comments
