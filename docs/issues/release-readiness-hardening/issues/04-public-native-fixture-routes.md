# 04 Public theme-instance native fixture routes and behavior matrix

Status: resolved

**Blocked by:** none

**What to build:** Implement the specialized native fixture behavior through exported theme instances over TerminalEnvironment.nativeThemeDefault before any scenario is called public coverage. Cover correct rich/linear interaction selection, initial drafts for cursor and long-line editing, resize draft behavior, repeat/reacquisition, validation recovery, redirected or dumb-output behavior, password help, cancellation/interruption/EOF outcomes, and session retirement with writer failure. The session-retirement fixture must use theme-owned feedback coexisting with a prompt across the shared session and prove writer failure retires the parked prompt while native console state is restored. Add compact Dart lifecycle-matrix coverage only where it exercises behavior through the public seam. See the [spec](../spec.md), especially “Public native lifecycle coverage and CI”.

## Acceptance criteria

- [x] Native fixtures counted as public coverage construct reusable exported theme instances and invoke parameterless prompt/feedback methods; direct constructors and the internal compatibility barrel are not used.
- [x] Required specialized fixture behaviors exist rather than merely being relabeled: rich/linear selection, initial drafts, resize behavior, repeat/reacquisition, validation recovery, output refusal/redirection, password help, cancellation/interruption/EOF, and writer-failure retirement.
- [x] The session-retirement fixture proves feedback/prompt coexistence, parked-prompt retirement on writer failure, and console restoration.
- [x] Compact public lifecycle Dart tests cover reusable prompts, rich/linear outcomes, EOF, cleanup/reacquisition, feedback coexistence, and failure recovery through the public seam.
- [x] Focused fixture, lifecycle, analyzer, and test commands pass.

## Comments

## Answer

Implemented the public native fixture seam in `test/text_input_public_native_app.dart`. That module imports only `package:trelis/trelis.dart`, constructs exported `PlainTheme` instances over `TerminalEnvironment.nativeThemeDefault`, and invokes parameterless prompt/feedback methods. `test/text_input_native_app.dart` now dispatches `public-` scenarios to this module instead of relabelling the compatibility implementation.

The public routes now preserve the specialized fixture setup instead of using one generic alpha prompt: explicit rich/linear/automatic selection, cursor and long-line initial drafts, resize draft width, repeatable prompt reuse plus theme reacquisition, validation-throw recovery on one reusable theme, stdout/redirected stderr selection, dumb-terminal refusal/fallback, password-help routing, cancellation/interruption/EOF outcomes, framed paste and Unicode input. The session-retirement route starts theme-owned spinner feedback, joins a parked native prompt in the same theme session, fails the shared writer through the feedback update, and observes the parked prompt retire; the Windows probe independently verifies console restoration.

Compact public lifecycle coverage in `test/public_theme_instance_test.dart` now explicitly includes rich versus linear outcomes and validation recovery through the public seam, alongside the existing reusable-prompt, EOF, cleanup/reacquisition, feedback-coexistence and writer-failure recovery tests.

Evidence on this Windows host:

- `dart test test/public_theme_instance_test.dart` — 23 tests passed before merge.
- After merging `integration/release-readiness-hardening`: `dart test test/public_theme_instance_test.dart test/public_multiline_input_test.dart` — all tests passed.
- `dart analyze` — no issues found after the merge.
- `dart format --output=none --set-exit-if-changed test/public_theme_instance_test.dart test/text_input_native_app.dart test/text_input_public_native_app.dart` — passed with no changes needed.
- Windows public native probes passed for `rich`, `linear-cursor`, `linear-long`, `resize`, `dumb-rich`, `session-retire`, `repeat`, `error`, `eof`, `escape`, `interrupt`, `redirected`, `stdout`, `paste`, `unicode`, and `dumb-auto` through `test/text_input_windows.ps1 -PublicApi`; reports included the expected result and restored console state. In particular, `session-retire` reported `retired` with state `503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`.

Execution limitations/scope boundaries: POSIX PTY execution was not possible on this Windows host. The committed Windows help probe still sends Ctrl+T and its conversion to real F1 events is ticket 03 scope, so ticket 04 does not claim corrected native modal-help keystroke evidence; the public password-help route is implemented, while F1 harness behavior remains for ticket 03. A temporary local probe substituting F1 key events still did not open help, confirming that the remaining native help evidence depends on ticket 03 rather than on this routing change.
