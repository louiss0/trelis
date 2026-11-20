# 02 Associate I/O with the selected output

Status: resolved

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
- [x] Tests with distinct outputs prove capabilities, rendering and identity follow the selected output, not global stdout; profile overrides work for scripted I/O.
- [x] Externally supplied streams stay open by default; test explicit ownership transfer and document that subscription cancellation can invoke caller stream cancellation behavior.
- [x] Test unavailable/redirected output, failed acquisition and restoration; no resource is leaked or inappropriate output profile silently selected.
- [x] Document stable shared identity expectations and the limitation that unidentifiable wrappers may overlap undetected; record test commands and results.

## Comments

Implemented an internal `TerminalEnvironment` seam that binds input, one selected output, that output's `OutputProfile`, acquisition/restoration and an optional stable ownership identity. Scripted, custom-adapter and native-fact constructors let the future theme owner receive one environment without adding invocation-level prompt configuration; the existing `terminal:` and direct `output:` calls still work. Red/green vertical slices covered profile and identity binding, caller-stream ownership, failed acquisition/restoration, conservative redirected-output facts, explicit scripted profile overrides, and the hard `NO_COLOR` restriction.

Commands and results (after merging `integration/adaptive-theme-presentation`, which was already up to date):

- `dart test test/terminal_environment_test.dart` — 11 passed.
- `dart test test/terminal_environment_test.dart test/terminal_io_test.dart test/output_profile_text_input_test.dart test/feedback_test.dart` — 42 passed.
- `dart test` — 4818 passed.
- `dart format --output=none --set-exit-if-changed .` — 221 files, 0 changed.
- `dart analyze` — no issues.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no legacy local tracker remains.

Key decisions: caller streams stay open unless `closeInput` explicitly transfers ownership, while subscription cancellation can still invoke caller stream cancellation behavior. Native profiles are derived from selected-output facts: redirected output gains no cursor, geometry, alternate-screen or colour capability. A selected `Stdout` is the default native identity; adapters may supply a shared identity, and a null identity is treated as unidentifiable. Direct `output:` feedback calls keep their existing explicit-colour behavior subject to non-empty `NO_COLOR`.

Honest gaps: native acquisition is supplied as a callback and was not exercised against a real terminal; no Windows/macOS native reader, human screen-reader, real light/dark visual, or true process-redirected-stdout evidence was collected. Synthetic native facts and scripted streams only. Distinct unidentifiable wrappers may still overlap undetected; conflict enforcement and lifecycle ownership belong to later theme-owner tickets.
