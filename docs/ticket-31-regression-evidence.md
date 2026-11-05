# Ticket 31 regression evidence (incomplete)

Baseline revision: `9ad9171fe662af6e1851ac6d3b9793f44a89aef0`. Local Windows version: 25H2, build 26200.9711; Dart 3.13.2 stable, windows_x64. Integration branch was at the baseline revision; `git merge integration/trelis-components` reported `Already up to date.`

At that revision `dart pub get` resolved 53 dependencies, `dart analyze` reported no issues, and `dart test` reported `473: All tests passed!`. This is not an audited 38-component rich/linear acceptance matrix.

The public TextInput backend was exercised using `powershell -NoProfile -ExecutionPolicy Bypass -File test/text_input_windows.ps1 -Scenario <scenario> -Report <temporary-report>`, once for each scenario below. The harness injects Windows console records and checks input/output console modes and cursor state before and after. Its stdout is redirected to capture the result; the prompt uses terminal stderr. It does not exercise real keyboard, clipboard, IME, layout, or rendered appearance.

| Scenario | Result |
| --- | --- |
| rich | PASS, `alpha` |
| escape | PASS, `cancel` |
| interrupt | PASS, `interrupt` |
| eof | PASS, `eof` (injected Ctrl+Z console record, not a closed terminal) |
| error | PASS, `alpha` in a subsequent session after validation throws |
| repeat | PASS, `alpha,alpha` |

For each case the recorded before/during/after state was `503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. The rich case submits the initial value; the other cases use linear interaction. This evidence is limited to the harness and scenarios, not every component or all stream combinations.

`wsl --list --verbose` reported no installed distributions. There is no configured Git remote or existing workflow in this worktree. The new workflow configures Windows, Linux, and macOS analysis and suite runs and the Windows harness; it has not been run on GitHub Actions. Linux/macOS native interactive lifecycle, real terminal rendering, clipboard, IME and keyboard layouts remain unexecuted. POSIX interactive support is not yet implemented: the shared backend explicitly returns unavailable off Windows. The requested 38-component public acceptance matrix and complete native platform coverage remain outstanding. None of these gaps is a pass.
