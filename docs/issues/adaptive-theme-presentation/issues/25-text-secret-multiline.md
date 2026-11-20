# 25 Migrate text, secret and multiline prompts

Status: ready-for-agent

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

- [ ] Exercise real TextInput, Password and Multiline components in rich and linear modes, including screen-reader presentation; retain their value types, validation and editing semantics.
- [ ] Render meaningful draft, validation, success and error states without relying on color; verify Unicode and ASCII with `NO_COLOR` and narrow output.
- [ ] Always show compact primary-action/help guidance: rich bottom, normal linear after content, and screen-reader essential instructions before each prompt, even with hidden instructions. Detailed help preserves draft and caret.
- [ ] Protect secret content in output, help, errors and screen-reader transcripts; use a secret-safe help route that never reinterprets literal secret input as commands.
- [ ] Independently test literal escaped or identified pasted command-shaped text across invalid retries, value-length limits versus help/cancel commands, rejected multiline paste in single-line fields with draft preserved, and bracketed-paste capability/cleanup where applicable. Document native limitations.
- [ ] Bind through internal theme ownership, resolved interaction and colors rather than adding competing readers or public per-invocation configuration; preserve component delegation and existing safety behavior.
- [ ] Test accepted, validation retry, cancellation, interruption, unavailable and `InputEnded` outcomes; sequential reuse starts from configured initial values, not previous answers, and concurrent prompt use is rejected.
- [ ] Add automated component and session regression tests for the cases above; record commands/results and missing native-terminal or human screen-reader evidence without claiming qualification.
