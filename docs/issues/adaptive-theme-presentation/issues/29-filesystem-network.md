# 29 Migrate filesystem and network prompts

Status: resolved

**Blocked by:** [25](25-text-secret-multiline.md)

**What to build:** Migrate PathInput, FilePicker, DirectoryPicker, IpAddressInput, UrlInput and EmailInput using theme-owned internal session and presentation seams. Preserve public calls until the coordinated cutover; follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Proposed examples — NOT IMPLEMENTED

```dart
final path = RailTheme().pathInput('Destination');
final result = await path.prompt();
```

```dart
final email = RailTheme().emailInput('Contact');
final first = await email.prompt();
final again = await email.prompt(); // Restarts from configured initial value.
```

## Acceptance criteria

- [x] Exercise every named real component in rich, linear and screen-reader modes, preserving filesystem navigation, filters, validation, typed values and existing outcomes.
- [x] Present focus, selected path, validation and unavailable states with readable text and non-color indicators; cover Unicode, ASCII, `NO_COLOR`, narrow layouts and screen-reader textual descriptions.
- [x] Always show compact primary-action/help hints at rich bottom or after normal linear content, and essential screen-reader instructions before the prompt, even when instructions are hidden. Help preserves path/query draft, focus and caret.
- [x] Independently verify safe editing: escaped or identified pasted command-shaped values survive invalid retries, help/cancel work even with short value limits, and recognized multiline paste into single-line fields is rejected while preserving the draft; capability-check and clean up paste reporting.
- [x] Test representative filesystem paths, file/directory filtering and inaccessible entries, IP address, URL and email validation and retries without weakening existing safety or changing domain semantics.
- [x] Delegate internally via the theme owner and resolved interaction/colors without starting a second external prompt or competing input reader; do not add per-invocation I/O configuration.
- [x] Test success, invalid retry, cancellation, interruption, unavailable and `InputEnded`, sequential reuse from configured initial values, and concurrent prompt rejection.
- [x] Add automated family/session tests and record commands/results and missing native-terminal or human screen-reader evidence; scripted coverage is not accessibility qualification.

## Comments

Added the internal, non-exported `lib/src/theme_filesystem_components.dart`
`ThemeFilesystemPrompt` seam with `path`, `filePicker`, `directoryPicker`,
`ipAddress`, `url` and `email` factories. Each instance captures immutable
configuration, owns one `ThemeSession`, layers its `ComponentColors` over the
period palette, constructs the real component inside the resolved period and
delegates with that session. No public constructor, factory or prompt
signature changed. Screen-reader periods receive sequential essential
instructions before the real prompt; rich and linear periods close with the
mandatory compact primary-action/help hint, shortened on narrow output while
keeping the help route visible.

Validation after merging `integration/adaptive-theme-presentation` (merge
reported `Already up to date.`):

- `dart test test/theme_filesystem_components_test.dart -r compact` — 40 passed.
- Focused regression set (`theme_filesystem_components`, `filesystem_migration`,
  `path_input`, `path_input_behavior`, `path_input_errors`,
  `filesystem_picker`, `network_input`, `url_input`, `email_input`) — 119 passed.
- `dart format --output=none --set-exit-if-changed .` — 315 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5502 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Decisions: the seam appends a compact hint because the real browser
components describe their stages but do not print a help route; the real
component keeps its own text, safety caveats, outcome types and filesystem
checks. Focus, selected paths, validation and review remain readable text with
the components' existing non-colour markers; no second renderer was added.
Tests cover all six components in rich, linear and screen-reader modes,
file/directory filtering and type rejection, inaccessible listings, typed IP
values with prefixes, URL/email retries, escaped and identified pasted
command-shaped values, multiline-paste rejection, detailed-help draft/focus/
caret preservation, hidden instructions, ASCII/Unicode/`NO_COLOR`/narrow
output, all outcome variants, sequential reuse, concurrent rejection, a single
shared reader release and one resolution callback shared with live feedback.

Gaps: all evidence is scripted or synthetic. No native terminal, real screen
reader, human accessibility, real light/dark visual or hardware bracketed-paste
check was performed, and no accessibility qualification is claimed. These real
components expose no submitted-value length setting, so help/cancel under
short values was exercised with one-character drafts rather than a configured
limit. Framed paste parsing and cleanup are exercised through the shared
reader; no terminal capability negotiation or paste enable/disable sequence
was added, and unframed paste still cannot be distinguished from typing. The
public cutover remains ticket 32.
