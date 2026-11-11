# Backend baseline and deterministic harness

**Status:** recorded; not an implementation or backend-gate pass

**Baseline production revision:** `80f4752e16a6e3b2451f2b87b9450e535ae3fa30`

**Recorded:** 2026-11-11

**Worktree:** `ticket/backend-01-baseline`

This is the B-BASE/B-PARITY starting point for the backend tracer bullets. The
production source was inspected at the revision above. This ticket adds only
test support, a public-seam harness test, and this evidence record; it makes no
runtime-library or dependency change. The working tree had that production
revision checked out before this ticket's test/evidence additions.

## Public inventory at the baseline

`lib/prompty.dart` exports `src/text_input.dart` and `src/feedback.dart`; the
`part` declarations in `text_input.dart` supply the remaining public component
classes. `test/prompty_test.dart` constructs all 38 exported components through
that package export.

### Interactive prompts (34)

| Family | Public component(s) | Accepted value |
| --- | --- | --- |
| Text and secret entry | `TextInput`, `Password`, `Autocomplete`, `Multiline` | `String` |
| Tag entry | `TagInput` | `List<String>` |
| Boolean choice | `Confirm`, `Checkbox`, `Toggle` | `bool` |
| Single choice | `Select<T>`, `Radio<T>`, `SearchSelect<T>`, `CommandPalette<T>`, `TimezoneSelect`, `TreeSelect<T>` | `T` (timezone is `String`) |
| Multiple/order choice | `MultiSelect<T>`, `SortableSelect<T>` | `List<T>` |
| Exact numeric | `Slider` | `String` |
| Exact range | `RangeSlider` | `(String, String)` |
| Structured time/date/duration/schedule | `TimeInput`, `DateInput`, `DurationInput`, `CronInput` | `({int hour, int minute, int? second})`, `CivilDate`, `DurationValue`, `CronExpression` |
| Filesystem | `PathInput`, `FilePicker`, `DirectoryPicker` | `String` |
| Key capture | `Keypress`, `KeyChordInput` | `KeyGesture`, `List<KeyGesture>` |
| Numeric/network | `NumberInput`, `PortInput`, `IPAddressInput` | `NumericAnswer?`, `int`, `IPAddressValue` |
| URL/email/colour/mask | `URLInput`, `EmailInput`, `ColorInput`, `MaskedInput` | `String`, `String`, `ColorValue?`, `MaskedValue` |

Every prompt returns `Future<PromptResult<T>>`. The public lifecycle/outcome
set is `Accepted<T>`, `Cancelled<T>`, `Interrupted<T>`, `InputEnded<T>`, and
`Unavailable<T>`. Current public sources are `SuppliedAnswer`, `SuppliedTags`,
and `ScriptedInput`; native invocation remains the no-source prompt API.
Current mode inputs are `rich`, `linear`, and `automatic`, with the documented
`mode`, user preference, application preference, automatic precedence.

### Feedback components (4)

| Component | Public lifecycle |
| --- | --- |
| `Text` | `present` writes literal-safe semantic text; it has no start/finish lifecycle. |
| `Progress` | `start`, `update`, `phase`, `setTotal`, explicit `finish`, or `dispose`. |
| `Spinner` | `start`, `update`, explicit `finish`, or `dispose`. |
| `MultiSpinner` | `start`, per-task `update`/`finishTask`, automatic all-task summary, or `dispose`. |

`FeedbackOutcome` remains explicit (`completed`, `failed`, `skipped`,
`cancelled`, `interrupted`): a progress value reaching its total is not an
outcome. Feedback exposes the selected `StringSink` and existing mode/
preference/supports-rich arguments, but it has no output-profile or session
API at this baseline.

## Deterministic harness

`test/support/backend_baseline_fixture.dart` deliberately remains test-only.
It calls only current public APIs and does not inspect private implementation
members.

- `RecordedOutput` is the selected-output `StringSink` recorder.
- `PromptFixture` supplies one public `ScriptedInput`, explicit `supportsRich`,
  a recorded selected output, and deterministic input chunks or `addError`.
- `EnvironmentFixture` holds a declared map rather than consulting
  `Platform.environment`; its baseline values are `TERM=dumb`, absent
  `COLORTERM`, and `NO_COLOR=1`.
- `TerminalGeometryFixture` requires positive caller-declared dimensions. No
  implicit virtual 80x24 terminal is supplied.
- `ManualClock` advances only when the scenario does, starting from a caller
  provided `DateTime`.
- `FailingOutput` fails every write with the caller-provided object and counts
  attempts.

`test/backend_baseline_harness_test.dart` establishes three public-seam tracer
bullets: scripted TextInput plus selected output; declared environment,
geometry, and time; and injected input/output failures. The error behavior is
observed through `TextInput.prompt` and `Text.present`, never through private
methods.

These fixtures make future tests reproducible; they do **not** claim that the
current production backend consumes injected environments, geometry, clocks,
or failures. It does not yet have a replaceable terminal I/O/output-profile
adapter or `TerminalSession.run`; those are later backend slices.

## Executed baseline verification

Environment observed while recording:

- Windows 11 25H2, build 26200 (Microsoft Windows NT 10.0.26200.0)
- Dart SDK 3.13.2 stable, `windows_x64`
- Host process input, stdout, and stderr were all redirected (`True`, `True`,
  `True`)
- `TERM=xterm-256color`, `COLORTERM=truecolor`; `NO_COLOR` expanded to an
  empty value during the environment capture (presence was not separately
  established)

The host values above are evidence context, not fixture input. The deterministic
fixture test declares its own values instead.

| Command | Actual result | Scope |
| --- | --- | --- |
| `dart pub get` | passed: dependencies resolved | package dependency resolution |
| `dart test test/backend_baseline_harness_test.dart --reporter expanded` | passed: 3 tests | selected public prompt/feedback seams and deterministic adapters |
| `dart test test/component_acceptance_matrix_test.dart --reporter expanded` | passed: 144 tests | existing rich/linear public component matrix, including overlap/recovery and representative task values |
| `dart format --output=none --set-exit-if-changed .` | passed: 120 files, 0 changed | package formatting |
| `dart analyze` | passed: no issues found | static analysis |
| `dart test --reporter compact` | passed: 642 test completions, ending `All tests passed!` | full package suite |
| `dart run tool/check_doc_links.dart` | passed: 151 relative links in 24 Markdown files | documentation links |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario repeat -Report doc/evidence/trelis-backend/baseline-text-input-repeat.txt` | passed: `alpha,alpha`; state `503:7:25:1 -> 503:7:25:1 -> 503:7:25:1` | injected Windows-console TextInput repeat lifecycle; [stored report](baseline-text-input-repeat.txt) |
| `powershell -NoProfile -ExecutionPolicy Bypass -File test/feedback_native_checks.ps1` | first execution **failed** in rich mode (details below); immediate sequential retry passed rich and linear, each with input mode `503 -> 503` | narrow Windows feedback probe |
| `python -m py_compile test/posix_terminal_pty.py` | passed | Python syntax only, **not** POSIX PTY execution |

The first feedback-native invocation ran while independent Dart checks were
also running. Its rich child reported `feedback native FAIL missing [Warning:
literal\\u001b[31m] from screen:  A` and exited 1; the wrapper stopped before its
linear scenario. It is retained as a failed/flaky baseline observation rather
than replaced by the immediate retry. The retry ran after the other commands
completed and printed both `feedback native rich narrow console PASS input mode
503 -> 503` and `feedback native linear narrow console PASS input mode 503 ->
503`. The different observations do not establish a cause or a broad feedback
native pass.

## Historical evidence retained, not promoted

`doc/ticket-31-regression-evidence.md` is retained as historical component and
Windows harness evidence. Its old test counts, injected-console-record results,
unexplained one-off rich input failure, and unavailable POSIX/CI execution are
not current passes. `doc/terminal-probe.md` remains a narrow Windows probe, not
a component backend or accessibility qualification. `doc/terminal-backend-
ticket-01-investigation.md` remains an incomplete source investigation.

## Pending and unavailable evidence

- Linux and macOS native PTY execution is unavailable in this Windows worktree;
  no physical or local substitute was used.
- GitHub Actions was not triggered and no CI run URL/artifact exists.
- The host process was redirected, so it does not provide a visible-terminal,
  geometry, rendering, keyboard, clipboard, IME, or NVDA observation.
- No agent-operated visible Windows terminal probe was performed for this
  baseline ticket.
- Existing test support cannot establish terminal state restoration, universal
  width/font agreement, output-profile behavior, a shared session lifecycle, or
  a whole-library accessibility claim.

The final backend gate must re-run affected evidence against its accepted
revision; this baseline publication is neither implementation nor a pass for
B-CAP through B-GATE.
