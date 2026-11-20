# 05 Establish the theme-owned session seam

Status: claimed

**Blocked by:** [01](01-shared-terminal-seam.md), [02](02-io-output-profile.md), [03](03-interaction-resolution.md)

**What to build:** Introduce an internal theme owner combining the shared terminal seam, one selected-output environment and interaction resolution. It lazily acquires resources through a common asynchronous first-operation path for prompts and feedback. Keep the existing public API buildable until the coordinated cutover; do not expose sessions to callers or add a public close method. See the [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(io: environment, interaction: preferences);
final answer = await theme.textInput('Name').prompt();
```

## Acceptance criteria
- [ ] Prompt-first and feedback-first internal tests show acquisition and interaction resolution before output, with component availability checked before successful prompt resolution is published.
- [ ] A theme-wide rich/screen-reader conflict prevents all output; unavailable explicit rich returns `Unavailable` for a prompt and a clear feedback error. Early failure and unavailable requests do not call the callback.
- [ ] Invoke the theme callback at most once per active period before rendering, publish the read-only value only after it succeeds, and clear it after cleanup; callback failure propagates after restoration and permits a fresh later attempt.
- [ ] Cover acquisition failure, cancellation during initialization and initialization fallback without leaks or premature output. Record tests and any unverified native behavior.
