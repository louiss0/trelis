# 34 Observe native hints and conservative locality

Status: resolved

**Blocked by:** [03](03-interaction-resolution.md), [05](05-theme-owned-session.md)

**What to build:** Add injectable native reader and locality observations feeding interaction resolution. Automatic hints are positive-only: negative or unknown observations never veto another affirmative hint; explicit on/off and explicit rich behavior take precedence. Native positives apply only in reasonably local interactive sessions. Linux and unsupported or failed native queries remain unknown. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual resolution, not a public API:
autoReader = appPositive || (localityEligible && nativePositive);
```

## Comments

Added internal `lib/src/hint_observations.dart`. Callers inject the platform
family, interactive flag, optional positive local attestation, environment
map and reader/remote/container probes; the library produces the existing
`InteractionFacts`. `ThemeSession` accepts `hints` and collects them once
during first-operation initialization, before publishing a value; cleanup
clears the period and a later period re-observes. Explicit `factsForPeriod`
still takes precedence. An immutable explicit conflict short-circuits before
any observation, while a merely unavailable request follows the inherited
facts path and publishes nothing.

Locality is conservative. A native positive is eligible only in an
interactive, positively attested local session. Non-empty `SSH_CONNECTION`,
`SSH_CLIENT` or `SSH_TTY` is remote; a positive Windows remote-session probe
is remote. Non-empty `TMUX`, `TMUX_PANE`, `STY`, `WINDOW` or systemd
`container`, a positive container probe, or a failed/throwing required remote
check is ambiguous. Container absence, unavailable checks, and a non-remote
result are neutral, never proof of locality. Only the documented `container`
environment variable and an injected probe are used: no `/.dockerenv`,
cgroup parsing, file probe or subprocess. These inherited indicators are
forgeable and describe one transport layer; multiplexer reattachment, nesting
and stale environments can misclassify. Reader probes run only on Windows or
macOS; Linux and unsupported platforms never call them. Failed queries are
carried as `failed` and, like negative and unknown observations, never select
or veto an affirmative application hint.

Validation on this branch after merging `integration/adaptive-theme-presentation`
(already up to date, no conflicts):

- `dart test test/hint_observations_test.dart test/hint_observations_session_test.dart test/theme_session_test.dart test/interaction_resolution_test.dart -r compact` — 53 passed.
- `dart test -r compact` — 4900 passed.
- `dart format --output=none --set-exit-if-changed .` — exit 0.
- `dart analyze` — no issues found.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files, no legacy local tracker.

Decisions: no native FFI binding, platform `Platform` read, public barrel
symbol or prompt signature was added. `platformFromName` keeps platform
detection injectable; the theme passes its `TerminalIo.environment` into the
observation seam. Conflict detection reuses the deterministic resolver rather
than duplicating its rule. No subprocess container detection exists.

Gaps: these are synthetic observations only. There is no Windows/macOS native
reader binding (35/36), no Windows Terminal/NVDA or macOS/VoiceOver human
evidence (37/38), no Linux signal, and no real SSH, RDP, tmux, screen,
container or multi-viewer validation. False positives and missed readers
remain possible; native enablement and the interaction release gate stay
blocked on their own tickets. Real light/dark visual qualification is also
outside this ticket.

## Acceptance criteria

- [x] Test explicit on/off and explicit rich precedence, conflicts and positive app hints combined with negative or unknown native hints.
- [x] Test interactive terminal eligibility and non-empty SSH_* indicators, recognized tmux and GNU screen, positive RDP and positively identified container contexts as ambiguous.
- [x] Test a failed required supported native locality check is ambiguous; unavailable container checks alone do not veto, and absence of indicators is not proof of locality.
- [x] Use documented safely accessible container signals only; never launch a subprocess for container detection. Document exact indicators and false-positive limitations.
- [x] Test unsupported platforms, Linux and failed native reader observations resolve to unknown without blocking; no negative observation vetoes an affirmative application hint.
- [x] Test observations once per active period, automatic cleanup and later reacquisition/re-detection; capture automated results and identify remaining platform validation.
