# 03 Native F1 help and harmless unassigned function keys

Status: resolved

**Blocked by:** [02](02-conpty-staging-and-diagnostics.md)

**What to build:** Reconnect every native help fixture to F1 and prove modal help behavior through real terminal harnesses. Split the existing ConPTY function-key coverage into an F1 contract (open help, do not nest, input remains modal, Escape restores prior screen/caret, ordinary input can still complete) and an unassigned-function-key control (no edit, corruption, or blockage). Windows TextInput scenarios cover normal and secret help, hidden-entry protection, repeated F1, Escape restoration, and final outcomes. VT-oriented scenarios use recognized SS3 or CSI F1 encodings; no release fixture may use Ctrl+T as help. See the [spec](../spec.md).

## Acceptance criteria

- [x] Windows console probes send actual F1 console key events and VT scenarios send recognized F1 encodings; no fixture uses Ctrl+T for help.
- [x] F1 opens component help, repeated F1 does not nest, typed input while help is open is not answer data, and Escape restores prior screen and caret state.
- [x] Secret entry is never disclosed through help; normal final outcomes still complete after dismissal.
- [x] An unassigned function key neither edits nor blocks the answer.
- [x] Corrected Windows native scenarios pass with staged waits and structured diagnostics.

## Comments

## Answer

Implemented real native F1 contracts without changing the production key binding. `test/text_input_windows.ps1` now writes scan-code-faithful console key records through `WriteConsoleInput` (`VK_F1`/`0x70`, scan code resolved with `MapVirtualKeyW`), uses bounded opening-paint and Left-key caret gates before capturing reference state, injects repeated F1 plus ordinary `ModalNoise9` while help is open, and requires exact screen and caret restoration after Escape. Secret canary non-disclosure and submit/interrupt/EOF outcomes remain harness assertions. A static probe scan confirms no Windows console fixture still uses the old `[char]20,84` Ctrl+T record.

The incoherent ConPTY `function-key` case was replaced in `test/multiline_conpty_windows.ps1` by two contracts: rich SS3-F1 modal help (open once, repeated F1 does not nest, modal noise is absent, one alternate-screen enter/leave pair occurs, Escape repaints the prompt, ordinary `abc` completes) and a recognized CSI-F5 unassigned-key control (the key neither contributes answer data nor blocks following input). Both use the ticket-02 staged input and structured diagnostic harness.

Diagnosis of the ticket-04 F1 limitation: the production Windows console decoder already mapped `VK_F1` to `\x1bOP`; a scanless F1 substitution could open help on this host. The reproduced caret-restoration failures before the new gates were consistent with reference capture racing the opening or Left-key repaint rather than with product key decoding, and a PowerShell command-parsing fault could also prevent the probe from reaching interaction. A mechanical key swap alone was therefore not a reliable contract. The observable opening-paint and caret gates address that diagnosis while scan codes make the injected records realistic. One real fixture defect was exposed and fixed in `test/text_input_public_native_app.dart`: the public password-help route collapsed an interrupted result into `wrong` instead of reporting `interrupt`.

Evidence on this Windows host:

- After merging `integration/release-readiness-hardening`: `powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1` — all 8 cases passed (`framed-command`, `typed-command`, `framed-multiline`, `editing`, `f1-modal-help`, `unassigned-function-key`, `application-navigation`, `rich-enter-ctrl-j`); successful diagnostic artifacts were cleaned.
- After the merge, all six public Windows console help probes passed with exit 0 through Windows PowerShell 5.1: `help-text-linear`/`rich` -> `alphXa`, `help-password-linear`/`rich` -> `accepted`, `help-password-interrupt-linear` -> `interrupt`, and `help-text-eof-rich` -> `eof`; every report also showed the pre/during/post console state restored. The same six compatibility-route probes also passed with exit 0 before the integration merge, which did not touch these harnesses. These probes intentionally spawn visible console windows on this host and did run.
- `dart test test/public_theme_instance_test.dart test/multiline_test.dart` — 47 tests passed.
- `dart format --output=none --set-exit-if-changed test/text_input_public_native_app.dart` — pass; `dart analyze` — no issues; `dart run tool/check_issue_tracker.dart` — pass; `dart run tool/check_doc_links.dart` — pass.
- PowerShell parser validation for both changed `.ps1` files — `powershell syntax OK`. `pwsh` and `PSScriptAnalyzer` are not installed on this host, so validation used Windows PowerShell 5.1 only.
