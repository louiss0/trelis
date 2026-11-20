# 02 Associate I/O with the selected output

Status: claimed

**Blocked by:** None

**What to build:** Define an internal environment binding input, selected output, that output's `OutputProfile`, acquisition/restoration and stable ownership identity when available. Support native and scripted/custom environments without exposing invocation-level session configuration as the future API. Keep existing public calls working until cutover. See the [spec](../spec.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final environment = TerminalEnvironment(
  input: input, output: output, profile: outputProfile,
  ownershipIdentity: terminalIdentity,
);
final theme = RailTheme(io: environment);
```

## Acceptance criteria
- [ ] Tests with distinct outputs prove capabilities, rendering and identity follow the selected output, not global stdout; profile overrides work for scripted I/O.
- [ ] Externally supplied streams stay open by default; test explicit ownership transfer and document that subscription cancellation can invoke caller stream cancellation behavior.
- [ ] Test unavailable/redirected output, failed acquisition and restoration; no resource is leaked or inappropriate output profile silently selected.
- [ ] Document stable shared identity expectations and the limitation that unidentifiable wrappers may overlap undetected; record test commands and results.
