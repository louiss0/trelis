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

`wsl --list --verbose` reported no installed distributions. Neither `docker` nor `podman` is installed or on PATH; their usual Docker Desktop and Podman installation paths were also absent. There is no configured Git remote. The workflow configures Windows, Linux, and macOS analysis and suite runs, the Windows harness, and `python3 test/posix_terminal_pty.py` on Linux and macOS. The PTY test exercises the public TextInput native path and checks terminal attributes after submit, Escape, Ctrl+C, Ctrl+D, a validation error and repeated sessions. It has not been executed on POSIX, and the current backend is expected to fail it because it returns unavailable off Windows. Python 3.13 on Windows successfully compiled the PTY test with `python -m py_compile test/posix_terminal_pty.py`; that is only a syntax check. The workflow has not been run on GitHub Actions.

Linux/macOS native interactive lifecycle, real terminal rendering, clipboard, IME and keyboard layouts remain unexecuted. POSIX interactive support is not yet implemented. The requested 38-component public acceptance matrix, actual Windows terminal EOF beyond the injected Ctrl+Z record, and complete native platform coverage remain outstanding. None of these gaps is a pass.
