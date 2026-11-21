# 32 Coordinate the breaking public API cutover

Status: resolved

**Blocked by:** [10](10-rail-ink-blue.md), [11](11-ascii-ink-blue.md), [12](12-double-ink-blue.md), [13](13-chevron-ink-blue.md), [14](14-colon-ink-blue.md), [15](15-box-rust.md), [16](16-bracket-rust.md), [17](17-block-rust.md), [18](18-branch-plum.md), [19](19-round-plum.md), [20](20-line-plum.md), [21](21-minimal-sepia.md), [22](22-plain-sepia.md), [23](23-form-sepia.md), [24](24-ledger-sepia.md), [25](25-text-secret-multiline.md), [26](26-boolean-and-basic-choices.md), [27](27-tree-search-order.md), [28](28-formatted-values.md), [29](29-filesystem-network.md), [30](30-key-capture.md), [31](31-feedback-components.md)

**What to build:** Replace static theme classes and public direct component constructors with reusable theme instances and instance methods, in one coordinated breaking cutover. Remove public invocation-level configuration, `SuppliedAnswer` and `SuppliedTags`; preserve public result and component-value types. Internal old/new coexistence is expand-migrate-contract only, not a permanent second public API. Migrate generators, generated files, all examples, tests, fixtures, exports and documentation together; never leave staged public breaks. Explain alternatives for supplied answers without promising scripted input is equivalent. This is an unstable signature cutover, not an accessibility claim. See the [spec](../spec.md), [design](../../../adaptive-theme-accessibility-design.md) and [plan](../../../adaptive-theme-implementation-plan.md).

## Illustrative example - PROPOSED NOT IMPLEMENTED

```dart
final theme = RailTheme(io: environment);
final prompt = theme.textInput('Name');
final result = await prompt.prompt();
// Last active component releases resources automatically.
```

## Acceptance criteria

- [x] All 15 themes and every interactive and feedback family compile through instance methods; external-package fixtures verify return types and reject static factories and direct constructors.
- [x] Public API inventory rejects invocation-time I/O, session, mode and presentation configuration, `SuppliedAnswer` and `SuppliedTags`; preserve result, choice and value types.
- [x] Update and run theme factory and test generators, generated-diff checks, analyzer, tests, examples and native fixtures where available in the same buildable change set; record commands and results.
- [x] Migration guidance covers constructors, parameterless prompt calls, feedback methods, color defaults, essential help and supplied-answer alternatives, explicitly noting scripted input is not always equivalent.
- [x] Test reusable prompts reset their configured initial value; EOF returns `InputEnded`, concurrent prompts are rejected and feedback can outlive a prompt.
- [x] Test automatic last-component cleanup, cleanup/start races, later reacquisition and re-detection, caller-owned streams, failures and callback behavior without a public close.
- [x] Mark the API unstable pending independent interaction and colour gates; preserve safety behavior and record unverified native and human evidence.

## Comments

Implemented a single coordinated cutover behind TDD slices. First tracer:
`dart test test/public_theme_instance_test.dart` failed because `RailTheme`,
`ThemePrompt` and `StructuralTheme` were not constructible/types. The public
barrel now exports theme instances and result/choice/value types only; direct
component construction remains in a package-internal compatibility library for
component-level tests, not in the public API.

Validation performed in this worktree:

- `dart pub get` succeeded in the library and external fixture package.
- `dart analyze`: No issues found.
- `dart test`: 5538 tests passed after the final public-API lifecycle tests.
- `dart format --output=none --set-exit-if-changed .`: 342 files, 0 changed, exit 0.
- `dart run tool/check_issue_tracker.dart`: passes (rerun after integration merge).
- `python tool/check_generated_diffs.py`: generated diff check ok (43 targets).
- `dart run tool/check_public_api.dart`: positive fixture ok; seven negative
  cases rejected (direct constructor, static factory, supplied answer/tags,
  invocation I/O, invocation mode, prompt configuration).
- `python tool/generate_theme_factories.py <slug>` and
  `python tool/generate_theme_tests.py <slug>` for all 14 generated themes.
- Examples: `dart run example/trelis_example.dart`, `plain_theme_example.dart`,
  `box_theme_example.dart`, `bracket_theme_example.dart` completed with
  accepted scripted answers and explicit feedback completion.
- Native fixture suites included in `dart test` passed on this host; no native
  terminal, screen reader or visible colour review was performed.

Design decisions: generated theme files are thin instance subclasses of a
shared `StructuralTheme`; component wrappers share one `ThemeSession` per theme
so one prompt and live feedback join the same active period. The external
fixture is a separate package with a path dependency and imports only
`package:trelis/trelis.dart`. The pre-cutover static namespaces were moved to
an internal test compatibility library so existing component-level tests keep
testing real components without reintroducing a second public API.

Unresolved gaps: Windows Terminal + NVDA and macOS VoiceOver human evidence,
native hint enablement, real light/dark visual review, coloured terminal
rendering, and screen-reader qualification remain with the independent release
gates (37-42). The default native theme environment is a best-effort
stdin/stdout binding; custom environments are the tested seam. Scripted I/O is
documented as non-equivalent to supplied answers.
