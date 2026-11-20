# 05 Establish the theme-owned session seam

Status: resolved

**Blocked by:** [01](01-shared-terminal-seam.md), [02](02-io-output-profile.md), [03](03-interaction-resolution.md)

**What to build:** Introduce an internal theme owner combining the shared terminal seam, one selected-output environment and interaction resolution. It lazily acquires resources through a common asynchronous first-operation path for prompts and feedback. Keep the existing public API buildable until the coordinated cutover; do not expose sessions to callers or add a public close method. See the [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final theme = RailTheme(io: environment, interaction: preferences);
final answer = await theme.textInput('Name').prompt();
```

## Acceptance criteria
- [x] Prompt-first and feedback-first internal tests show acquisition and interaction resolution before output, with component availability checked before successful prompt resolution is published.
- [x] A theme-wide rich/screen-reader conflict prevents all output; unavailable explicit rich returns `Unavailable` for a prompt and a clear feedback error. Early failure and unavailable requests do not call the callback.
- [x] Invoke the theme callback at most once per active period before rendering, publish the read-only value only after it succeeds, and clear it after cleanup; callback failure propagates after restoration and permits a fresh later attempt.
- [x] Cover acquisition failure, cancellation during initialization and initialization fallback without leaks or premature output. Record tests and any unverified native behavior.

## Comments

Added the internal, non-exported `lib/src/theme_session.dart` owner. One
`TerminalEnvironment` supplies input, selected output, profile, acquisition and
identity; the common first-operation path resolves interaction and colour with
the merged resolvers, checks component availability, invokes the callback once,
publishes a read-only interaction value, and acquires the shared terminal
before any rendered output. Prompt and feedback runners join one active period;
the last participant releases it and clears the published value. A real
`TextInput` prompt and `Text` feedback were driven through the owned
`TerminalSession` in tests. No public barrel symbol, prompt signature or public
close method was added.

Validation on this branch:

- `dart test test/theme_session_test.dart` — 13 internal tests passed.
- `dart test test/theme_session_test.dart test/terminal_session_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_session_feedback_test.dart test/terminal_environment_test.dart test/interaction_resolution_test.dart test/color_resolution_test.dart -r compact` — 91 passed.
- `dart test -r compact` — 4888 passed.
- `dart format --output=none --set-exit-if-changed .` — 231 files, 0 changed.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker.

Decisions: explicit rich remains requested but is rejected by integration when
the selected output lacks rich support, so unavailability is distinct from a
configuration conflict. A failed injected facts source falls back to the
environment profile instead of blocking a prompt; cancellation during
initialization returns `Cancelled` for prompts and `ThemeSessionCancelled` for
feedback without acquiring resources or publishing a value. Internal delegation
reuses the active handle instead of opening another period or hitting the
external concurrent-prompt guard.

Gaps: all tests are synthetic or scripted; no native console, Windows/macOS
screen-reader, human reader, real light/dark visual or background-query evidence
is claimed. Background query, cross-theme overlapping-identity enforcement,
full component migration and primary-versus-cleanup failure aggregation remain
later tickets; none is implied by this seam.
