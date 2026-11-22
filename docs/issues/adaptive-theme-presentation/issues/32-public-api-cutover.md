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
- `dart test`: 5527 tests passed after the final public-API lifecycle tests.
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

2026-11-22 - Consolidated review fixes on detached worktree prompty-32-35 at
389fe3c:

- `TerminalEnvironment.nativeThemeDefault({Stdout? output})` now returns a
  native marker environment: prompts run through the existing
  handle-preserving console transport (`_terminal`/`_promptOnNativeConsole`,
  `_consoleInput`/`_posixInput`, per-prompt acquire/restore and resize/paste
  handling) instead of a Dart stdin subscription. `usesNativeConsole` is set
  only by this factory and cannot be selected by scripted or custom
  environments; the marker stream is never subscribed and the outer lease is a
  no-op by design. The profile getter re-observes the selected output on each
  use. The session background query remains honestly unavailable on the
  marker since it has no selected input; no competing native reader was added.
- All 34 public interactive factory bodies now construct the component at
  public creation via a `.prompt` tearoff, so configuration - including
  mutable `choices`, `defaultValues`, `supplementaryHelp`, `maskedInput`
  templates and `multiSpinner` task names - is captured once. 8 component
  constructors and the formatted-prompt create seam now snapshot
  `supplementaryHelp` with `List.unmodifiable`; `maskedInput` templates and
  `timezoneSelect` unavailable collections are snapshotted at the public
  factory boundary. Live feedback components still build on start; their
  names and configuration are captured at creation.
- Passive `COLORFGBG` advisory wired into `_defaultColorFacts`: only the exact
  2- or 3-integer form is accepted; final `0` reports dark, `7`/`15` light;
  custom ANSI palette indices are not modelled and stay unavailable. Explicit
  `ColorPreferences.background` and the bounded query take precedence;
  `NO_COLOR` still strips colour.
- Removed the unreachable duplicate `ThemeSessionColorLayering` extension and
  removed `InteractionFacts`, `InteractionResolution`, `InteractionConflict`,
  `InteractionUnavailable` and `ColorDetectionFacts` from the public barrel;
  `InteractionPreferences`, `ResolvedInteraction` and the hint observation
  types remain.
- `tool/check_public_api.dart` now analyses machine format and requires each
  case's expected diagnostic codes. Negative snippets are one hidden name per
  case: the 38 legacy concrete component classes, internal Theme* wrappers,
  the 5 removed resolver fact/outcome types and the hidden resolver
  functions, plus split feedback present/start configuration cases
  (UNDEFINED_NAMED_PARAMETER), theme_close (UNDEFINED_METHOD) and per-
  parameter invocation rejection at the `.prompt()` boundary.
- Writer failures on the shared output path now retire all live feedback
  participants in the active period and fail prompts parked on input with the
  original error, via an internal `onWriterFailure` callback wired to
  `_ThemePeriod.writerFailed`; feedback `finish` publishes its cleanup
  future before running end/stop so synchronous reentrant calls share the
  same outcome, and a failed `startFeedback` still stops partially
  initialised producers.

Validation today (Windows 10.0.26200.9974, Dart 3.13.2 windows_x64):

- `dart analyze`: no issues found.
- `dart test test/public_theme_instance_test.dart -r expanded`: 20 passed
  (new capture-snapshot, maskedInput template capture, COLORFGBG and writer-
  failure lifecycle tests, including a reentrant stop during a finish write
  failure sharing the same cleanup outcome; passive hint sensitivity-checked
  by temporarily unwiring `passiveBackground`, which failed only the light
  case).
- `dart test test/theme_session_feedback_lifecycle_test.dart
  test/theme_session_coordinated_feedback_test.dart -r expanded`: 23 passed.
- `dart test test/theme_session_cleanup_test.dart -r expanded`: 6 passed.
- `dart test test/windows_reader_hint_test.dart -r expanded`: 6 passed.
- `dart run tool/check_public_api.dart`: positive fixture ok; every negative
  case rejected with its expected diagnostic code (per-name hidden inventory
  cases included).
- `python tool/check_generated_diffs.py`: ok (43 targets).
- Native public routes via `test/text_input_windows.ps1 -PublicApi`
  (fixture `_runPublicScenario`, `PlainTheme` on
  `nativeThemeDefault(output: stderr)`): PASS repeat `alpha,alpha`, error
  `alpha`, interrupt, eof, redirected, rich `alpha`, help-text-rich `alphXa`,
  help-password-linear `accepted`, escape `cancel`; console state restored on
  every run (`503:7:25:1` before and after). After the shared-writer failure
  callback landed in `TerminalSession`, public repeat and error were re-run
  and still PASS with state restored.
- Known limitation: `linear-cursor` fails its harness caret assertion on
  BOTH the legacy and public routes; that establishes a pre-existing,
  unresolved harness behavior rather than a proven environmental cause or a
  cutover regression. The native public API already existed at baseline
  389fe3c - only the new fixture route and output argument were added - so a
  native pre-fix failure was not recorded; the new public native routes pass
  as listed above.

Final gate (same platform): `dart test -r expanded` full suite 5543 tests,
all passed (2:41); `dart analyze` clean; `dart format --set-exit-if-changed .`
342 files 0 changed; `tool/check_issue_tracker.dart` 177 files ok;
`tool/check_doc_links.dart` 1201 links ok after repairing a pre-existing
CP1252 byte sequence present at base 389fe3c in `19-round-plum.md`
(re-encoded UTF-8 to unblock the checker; unrelated to this change); `check_generated_diffs.py` 43 targets ok;
`check_public_api.dart` rerun: 74 negative cases all rejected with expected
codes; `windows_reader_fixture.dart` observation `negative`, binding
available.

Remaining gaps unchanged: native/screen-reader qualification, real
NVDA/Windows Terminal evidence and human light/dark visual review remain with
the independent release gates; the API stays marked unstable.
