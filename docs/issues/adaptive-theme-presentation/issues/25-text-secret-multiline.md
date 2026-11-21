# 25 Migrate text, secret and multiline prompts

Status: resolved

**Blocked by:** [08](08-text-input-tracer.md), [09](09-state-and-compact-help.md)

**What to build:** Migrate TextInput, Password and Multiline through the theme-owned internal presentation and session seams, preserving existing public calls until the coordinated cutover. Follow the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md). Verify editor safety within this family; there is no preliminary standalone safety audit.

## Proposed examples — NOT IMPLEMENTED

```dart
final name = RailTheme().textInput('Name');
final first = await name.prompt();
final second = await name.prompt(); // Starts from the configured initial value.
```

```dart
final theme = RailTheme();
final secret = theme.password('Password');
final result = await secret.prompt();
```

## Acceptance criteria

- [x] Exercise real TextInput, Password and Multiline components in rich and linear modes, including screen-reader presentation; retain their value types, validation and editing semantics.
- [x] Render meaningful draft, validation, success and error states without relying on color; verify Unicode and ASCII with `NO_COLOR` and narrow output.
- [x] Always show compact primary-action/help guidance: rich bottom, normal linear after content, and screen-reader essential instructions before each prompt, even with hidden instructions. Detailed help preserves draft and caret.
- [x] Protect secret content in output, help, errors and screen-reader transcripts; use a secret-safe help route that never reinterprets literal secret input as commands.
- [x] Independently test literal escaped or identified pasted command-shaped text across invalid retries, value-length limits versus help/cancel commands, rejected multiline paste in single-line fields with draft preserved, and bracketed-paste capability/cleanup where applicable. Document native limitations.
- [x] Bind through internal theme ownership, resolved interaction and colors rather than adding competing readers or public per-invocation configuration; preserve component delegation and existing safety behavior.
- [x] Test accepted, validation retry, cancellation, interruption, unavailable and `InputEnded` outcomes; sequential reuse starts from configured initial values, not previous answers, and concurrent prompt use is rejected.
- [x] Add automated component and session regression tests for the cases above; record commands/results and missing native-terminal or human screen-reader evidence without claiming qualification.

## Comments

Added the internal, non-exported `lib/src/theme_text_components.dart`
`ThemeTextPrompt` seam with `text`, `secret` and `multiline` factories. Each
instance captures immutable configuration, owns one `ThemeSession`, constructs
the real component inside the resolved period, and delegates with that session
so input, output, mode, colour and lifecycle come from one owner. The owner
handle now exposes `presentationMode` and `componentColors`; the ticket 08
tracer uses the same helpers instead of its duplicate local resolution.
Screen-reader prompts receive sequential essential instructions before the
component prompt, with the secret route kept on Ctrl+T and never treating
secret text as a command.

Editor safety changes: advertised `/help` and `/cancel` remain typeable under a
smaller submitted-value limit, while the limit is enforced again on the value
actually submitted (including escaped literals). Identified paste never gets
that exemption. Linear multiline guidance now states that `/help` opens help
and that `/done` accepts. No public constructor, factory, prompt signature or
export was changed.

Validation after merging `integration/adaptive-theme-presentation` (merge
reported `Already up to date.`):

- `dart test test/theme_text_components_test.dart -r compact` — 19 passed.
- Focused regression set (`text_input`, `password`, `multiline`,
  `text_input_help`, `linear_text_input_events`, `editable_probe`, both tracer
  suites and `component_acceptance_matrix`) — 249 passed.
- `dart format --output=none --set-exit-if-changed .` — 255 files, 0 changed.
- `dart analyze` — no issues found.
- `dart test -r compact` — 5021 passed.
- `dart run tool/check_issue_tracker.dart` — 177 Git-backed tracker files; no
  legacy local tracker remains.

Decisions: state text stays with the real components (sequential draft and
cursor reports, component validation messages, accepted answer or hidden-value
result) so no colour-only state or second renderer was introduced. The themed
seam emits only screen-reader-before content; rich and linear component hints
already occupy the bottom/after-content positions. `NO_COLOR`, ASCII, Unicode,
narrow geometry, hidden instructions, detailed-help draft/caret preservation,
command/paste/limit interactions, multiline paste rejection, secret
non-disclosure, outcome variants, reuse, concurrent rejection and shared-reader
release are covered by scripted tests.

Gaps: all evidence is scripted or synthetic. No native terminal, real screen
reader, human accessibility, real light/dark visual or bracketed-paste hardware
check was performed, and no accessibility qualification is claimed. Framed
paste is parsed by the existing shared reader and that reader is shown to be
released once per period; no terminal capability negotiation or paste-enable /
disable control sequence was added, and unframed paste still cannot be
distinguished from typing. Stricter submitted-value enforcement applies to the
affected editor path; other component families and the public cutover remain
later tickets.
