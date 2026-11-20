# 33 Route bounded background queries through the owned reader

Status: resolved

**Blocked by:** [02](02-io-output-profile.md), [04](04-colour-resolution.md), [05](05-theme-owned-session.md)

**What to build:** Implement an OSC background query through the theme-owned input reader, never a competing stdin subscription. Query only eligible interactive selected output when enabled and effective color is available. Cache at most one attempt per active period; use a fixed library timeout and safely fall back. Resolve explicit selection > valid query > passive hint > dark. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual precedence, not a public API:
background = explicit ?? validQuery ?? passiveHint ?? dark;
```

## Comments

Implemented an internal OSC 11 background query. `lib/src/background_query.dart`
parses only complete `rgb:` replies (BEL or ST), maps them by relative
luminance, and owns the fixed 250 ms bound. `SharedTerminalReader` consumes a
valid reply while a query waits; partial, malformed, unsolicited and late bytes
stay in the owned reader in their original order. `TerminalSession.queryBackground`
writes the request through the shared writer and reads through the shared
reader, so no second stdin subscription is created. `ThemeSession` runs one
query inside the first-operation path before the callback or any output,
merges the observation into colour facts, and re-resolves colours from
explicit choice > valid query > passive hint > dark. One attempt is cached per
active period; cleanup closes the reader and a later period may query again.

Commands and results after merging `integration/adaptive-theme-presentation`
(already up to date):

- `dart test test/background_query_test.dart test/theme_background_query_test.dart test/theme_session_test.dart test/shared_terminal_reader_test.dart test/terminal_session_test.dart -r compact` — 37 passed.
- `dart test -r compact` — 4901 passed.
- `dart format --output=none --set-exit-if-changed .` — 234 files, 0 changed.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.

Decisions: a query needs an interactive selected output, effective colour, and
enabled automatic background selection. A non-empty environment `NO_COLOR`
suppresses querying even when injected facts omit it; failed query writes and
timeouts fall back without blocking initialization. Scripted query responses
use declared RGB colour depth; automatic native depth remains conservative
under the existing resolver.

Gaps: all evidence is synthetic or scripted. No native terminal response, real
light/dark visual review, human screen-reader check, or live SSH, tmux, screen,
RDP or container evidence was collected. Native OSC support, terminal reply
variants and actual keyboard/paste interleaving with a real terminal remain
unverified here.

## Acceptance criteria

- [x] Test explicit light/dark precedence, valid response, passive hint and dark fallback, including unsupported terminals and a fixed bounded timeout.
- [x] Test query disabled, non-empty `NO_COLOR`, effective no-color depth and redirected/noninteractive output emit no query.
- [x] Test keyboard bytes and bracketed paste interleaved with responses retain their exact order and content; no competing input reader is created.
- [x] Test partial, malformed, unsolicited and late responses are preserved as input rather than swallowed; a valid timely response alone is consumed.
- [x] Test prompt-first and feedback-first initialization waits for resolution or fallback before rendering, including query and acquisition failure.
- [x] Test one attempt per active period, shared caching and automatic cleanup after the last component; a later active period reacquires and may query again.
- [x] Record automated test results and real-terminal observations or explicitly list missing native evidence.
