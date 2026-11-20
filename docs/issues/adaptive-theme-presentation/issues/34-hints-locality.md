# 34 Observe native hints and conservative locality

Status: claimed

**Blocked by:** [03](03-interaction-resolution.md), [05](05-theme-owned-session.md)

**What to build:** Add injectable native reader and locality observations feeding interaction resolution. Automatic hints are positive-only: negative or unknown observations never veto another affirmative hint; explicit on/off and explicit rich behavior take precedence. Native positives apply only in reasonably local interactive sessions. Linux and unsupported or failed native queries remain unknown. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
// Conceptual resolution, not a public API:
autoReader = appPositive || (localityEligible && nativePositive);
```

## Acceptance criteria

- [ ] Test explicit on/off and explicit rich precedence, conflicts and positive app hints combined with negative or unknown native hints.
- [ ] Test interactive terminal eligibility and non-empty SSH_* indicators, recognized tmux and GNU screen, positive RDP and positively identified container contexts as ambiguous.
- [ ] Test a failed required supported native locality check is ambiguous; unavailable container checks alone do not veto, and absence of indicators is not proof of locality.
- [ ] Use documented safely accessible container signals only; never launch a subprocess for container detection. Document exact indicators and false-positive limitations.
- [ ] Test unsupported platforms, Linux and failed native reader observations resolve to unknown without blocking; no negative observation vetoes an affirmative application hint.
- [ ] Test observations once per active period, automatic cleanup and later reacquisition/re-detection; capture automated results and identify remaining platform validation.
