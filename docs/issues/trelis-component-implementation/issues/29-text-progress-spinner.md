# 29: Deliver Text, Progress, and Spinner

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver feedback-only public Text, Progress and Spinner classes. Applications can present safe literal semantic text, determinate/indeterminate progress and activity in plain-rich or linear output without these components reading input, taking focus or owning cancellation. Output uses meaningful bounded text and preserves actual outcomes.

**Blocked by:**
- [03: Deliver TextInput and the shared public prompt-session foundation](03-text-input-session-foundation.md)

**Status:** resolved

- [x] Text treats content literally, renders unsafe controls harmlessly, provides readable semantic labels where needed and never implicitly interprets raw ANSI.
- [x] Linear progress reports start, meaningful phase/milestones and final outcome without animation frames or unchanged heartbeat lines.
- [x] Provisional configurable linear numeric defaults are 10-percentage-point milestones, at most one intermediate numeric update per five seconds, coalescing to latest value; final outcome is immediate.
- [x] Unknown totals are explicitly indeterminate; invalid determinate updates are rejected without clamping, and 100 percent/disposal never implies success.
- [x] Nonanimated rich feedback retains layout with explicit static state and actual state/value updates; explicit completed/failed/skipped/cancelled/interrupted outcomes retain meaning and finalized tasks ignore stale updates.
