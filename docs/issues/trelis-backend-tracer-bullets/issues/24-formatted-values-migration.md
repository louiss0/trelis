# 24: Migrate formatted-value inputs

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Use NumberInput, PortInput, IPAddressInput, EmailInput, ColorInput and DurationInput with their original typed interpretations and compact guidance.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-COMPAT](../../trelis-backend-implementation/spec.md#b-compat).

- [x] Preserve numeric conventions/precision/nullable answers, network/CIDR/zone, SMTPUTF8, colour syntax and duration-mode contracts.
- [x] Separate minimal active-format cues from detailed syntax help and interpretation/preview.
- [x] Keep availability/reachability/deliverability/transport and similar component limitations truthful and visible when relevant.
- [x] Verify unchanged accepted values, callbacks and explicit outcomes with distinguishable configuration forwarding.
- [x] Exercise all six public components in rich/linear shared and standalone scenarios, including validation/help.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

**Combined integration merge.** Merged follow-up branch tip `fd9e20f` as `74c5171` without conflict. All three previews use `_SessionOutputSink`, and email retains the terminal output fallback; this resolves the earlier open guarded-writer follow-up. At combined revision `74c5171`, 275 targeted tests and 813 full-suite tests passed; `dart analyze` reported no issues, changed-Dart formatting reported 8 files / 0 changed, and the doc-link check reported 153 links in 54 files. Native/GUI/cross-platform limitations remain as documented.


Merged to integration as `6368698`, followed by `9a2bcbf` reconciling prose assertions with shared wrapping (mutation check retained). Post-merge: 746 full-suite tests, 64 formatted-input tests and 21 session tests passed; analysis, changed-test formatting and doc links passed. Preview writes bypassing the guarded session writer remain an OPEN correctness follow-up, not an accepted B-SESSION/B-FAIL exception; worker assigned. The email preview's selected `TerminalIo` output fallback is included in that follow-up. Native/GUI/cross-platform gates remain pending.

## Answer

Implemented on `ticket/backend-24-formatted-values` in commits `ecb043b756a3ce3b652112f43cbdbf665a71496e` (implementation, tests and README) and `fb624d091d39b6e9f979356a39d7a3accb42dba5` (evidence), on top of the integration merge `9f573f3` whose base is integration tip `9d6ecbe`. Merging this branch into integration is deliberately left to the parent.

`NumberInput`, `PortInput`, `IPAddressInput`, `EmailInput`, `ColorInput` and `DurationInput` now open with a compact active-format cue and keep the detailed syntax, examples, interpretation rules and truthfulness caveats in component help (`Ctrl+T` in rich mode, `/help` in linear mode). Component help appends caller `supplementaryHelp`, retains the shared editing/validation help, and stays reachable under every `InstructionDisplay` policy (`hidden`, `compact`, `expanded`, `themeDefault`). The ticket also fixed two `DurationInput` gaps found while auditing: its opening still repeated the whole grammar instead of a compact mode cue, and its live interpretation was written to `stderr` rather than the shared session output. Accepted values, callbacks, previews and the distinct `Accepted`/`Cancelled`/`Interrupted`/`InputEnded`/`Unavailable` outcomes are unchanged; `allowZero`, `cidr`/`scoped`, `smtpUtf8`, numeric convention/precision/nullability, `required`, `durationMode` and `signed` are each verified through distinguishable behavior. README guidance for the six inputs now describes the cue/help split, the shared invocation/instruction/help/palette options and the unchanged limitations.

Verification on Windows NT 10.0.26200.0 (`windows_x64`) with Dart SDK 3.13.2: `dart format --output=none --set-exit-if-changed lib/src/duration_input.dart test/formatted_values_migration_test.dart` passed with no changes; the six formatted-value suites passed 64 tests; `dart analyze` reported no issues; `dart run tool/check_doc_links.dart` checked 152 links in 43 files; the full suite passed 724 tests. A mutation check confirmed the suite fails when a component's active-format cue is removed. Evidence and limitations are recorded in `assets/evidence/trelis-backend/24-formatted-values-migration.md`; native PTY, visible GUI/NVDA, resize/modal/fault-path, Linux/macOS CI and the final backend gate remain outstanding, and the repository-wide format gate still reports three files left unformatted by earlier tickets.

## Comments

**Follow-up review fix (2026-11-13).** The follow-up review established that the limitation recorded above was a contract defect, not merely missing evidence: the colour preview (`color_input.dart`), duration interpretation (`duration_input.dart`) and email domain interpretation (`url_email_input.dart`) selected `session._output` directly and bypassed the session's serialized guarded writer, so a failed selected output during a preview did not retire the session and a later live-region or prompt write could still reach the failed writer (B-SESSION/B-FAIL). The email interpretation also omitted the `terminal?.output` fallback the other two inputs already had.

Fixed on `ticket/backend-24-formatted-values` in `1afacd8` (`fix: serialize formatted-value preview writes`) with evidence updated in `fd9e20f`, based on integration tip `9a2bcbf` (the migration itself merged as `6368698`). All three preview paths now write through the existing private `_SessionOutputSink`, so every session write goes through `_writeShared`; standalone `ScriptedInput`, `output:` and `terminal:` routing is unchanged, and the email interpretation now follows `terminal.output`. No shared editor code changed.

New public-seam tests in `test/formatted_values_migration_test.dart`: each of the three previews is made to fail its selected output, proving the original writer failure surfaces unchanged, the session is retired before the scope ends, a late feedback-region update writes nothing, another attached prompt is refused with `StateError`, and a canary in the private writer diagnostic never reaches output; a recording `TerminalIo` test proves the email interpretation follows the selected terminal output. Each scenario was red before its fix (`late updates must not reach a failed writer`; `the interpretation must use the selected terminal output`) and the red/green was re-verified per file by reverting each fix individually.

Verification at the follow-up tip on Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK 3.13.2: the four touched files pass `dart format --output=none --set-exit-if-changed`; the formatted-value suites plus `terminal_session_failure_recovery_test.dart`, `terminal_session_feedback_test.dart` and `terminal_io_test.dart` passed 84 tests; `dart analyze` reported no issues; `dart run tool/check_doc_links.dart` checked 152 links in 45 files; the full suite passed 748 tests. The shared-writer failure evidence is deterministic scripted injection for these three preview paths only; native write failures, a failure while modal help owns the screen, cleanup-also-fails fallback and the three pre-existing unformatted test files remain outstanding and are recorded in the evidence limitations.
