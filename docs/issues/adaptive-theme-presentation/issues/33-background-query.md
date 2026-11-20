# 33 Route bounded background queries through the owned reader

Status: ready-for-agent

**Blocked by:** [02](02-io-output-profile.md), [04](04-colour-resolution.md), [05](05-theme-owned-session.md)

**What to build:** Implement an OSC background query through the theme-owned input reader, never a competing stdin subscription. Query only eligible interactive selected output when enabled and effective color is available. Cache at most one attempt per active period; use a fixed library timeout and safely fall back. Resolve explicit selection > valid query > passive hint > dark. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual precedence, not a public API:
background = explicit ?? validQuery ?? passiveHint ?? dark;
```

## Acceptance criteria

- [ ] Test explicit light/dark precedence, valid response, passive hint and dark fallback, including unsupported terminals and a fixed bounded timeout.
- [ ] Test query disabled, non-empty `NO_COLOR`, effective no-color depth and redirected/noninteractive output emit no query.
- [ ] Test keyboard bytes and bracketed paste interleaved with responses retain their exact order and content; no competing input reader is created.
- [ ] Test partial, malformed, unsolicited and late responses are preserved as input rather than swallowed; a valid timely response alone is consumed.
- [ ] Test prompt-first and feedback-first initialization waits for resolution or fallback before rendering, including query and acquisition failure.
- [ ] Test one attempt per active period, shared caching and automatic cleanup after the last component; a later active period reacquires and may query again.
- [ ] Record automated test results and real-terminal observations or explicitly list missing native evidence.
