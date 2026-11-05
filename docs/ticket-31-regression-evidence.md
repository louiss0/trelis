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

For each case the recorded before/during/after state was `503:7:25:1 -> 496:7:25:1 -> 503:7:25:1`. The rich case submits the initial value; the other cases use linear interaction. After the POSIX implementation the six cases were rerun and passed; additional TextInput harness scenarios `concurrent`, `redirected`, `stdout`, `paste`, and `unicode` also passed with the same state restoration. These use injected console records. This evidence is limited to the harness and scenarios, not every component or all stream combinations.

`wsl --list --verbose` reported no installed distributions. Neither `docker` nor `podman` is installed or on PATH; their usual Docker Desktop and Podman installation paths were also absent. There is no configured Git remote. The workflow configures Windows, Linux, and macOS analysis and suite runs, the Windows harness, and `python3 test/posix_terminal_pty.py` on Linux and macOS. The PTY test exercises the public TextInput native path and checks terminal attributes after submit, Escape, Ctrl+C, Ctrl+D, a validation error and repeated sessions. It has not been executed on POSIX. A POSIX backend has been implemented, but its behavior and the PTY test remain unverified on Linux and macOS. Python 3.13 on Windows successfully compiled the PTY test with `python -m py_compile test/posix_terminal_pty.py`; that is only a syntax check. The workflow has not been run on GitHub Actions.

## Public acceptance matrix increment

`dart test test/component_acceptance_matrix_test.dart --reporter expanded` ran 16 tests on Windows: TextInput, Password, Multiline, Confirm, Checkbox, Toggle, Select and Radio each have one rich and one linear case. All 16 passed. This increment is not the complete 38-component matrix; the other 30 components do not yet have cases in this matrix file. Existing tests elsewhere are not counted as matrix cases. `dart analyze` reported no issues and the full `dart test --reporter compact` suite reported 489 passed after this increment.

## Windows native checks at `f383fdc`

The following were run with `powershell -NoProfile -ExecutionPolicy Bypass -File test/<name>.ps1`. Each listed wrapper exited 0; their printed cases are listed, not extrapolated to untested scenarios:

| Check | Observed cases |
| --- | --- |
| `color_input_native_checks` | rich and linear `#1234` |
| `duration_input_native_checks` | elapsed rich/linear `1s`; calendar rich/linear `1mo` |
| `feedback_native_checks` | rich and linear narrow console; input mode restored |
| `filesystem_picker_native_checks` | file rich; directory linear and rich, including links/cycle (five cases in report file) |
| `masked_input_native_checks` | masked, adaptive, paste, adaptive-paste: each rich and linear |
| `network_input_native_checks` | port and IP: each rich and linear |
| `number_input_native_checks` | rich and linear; user preference override and stable draft |
| `url_email_native_checks` | URL and email: each rich and linear |
| `cron_input_console_checks` | rich, linear, rich-cancel, linear-cancel |
| `date_input_console_checks` | rich and linear Buddhist calendar date |

Additionally, each of `autocomplete`, `command_palette`, `cron_input`, `date_input`, `editable_probe`, `key_capture`, `multiline`, `multi_select`, `password`, `path_input`, `search_select`, `slider`, `sortable_select`, `tag_input`, `tag_input_edit`, `tag_input_remove`, `terminal_probe`, `timezone_select`, `time_input`, and `tree_select` was run once with its `test/<name>_windows.ps1` default scenario and an explicit temporary `-Report`; all exited 0 and reported PASS. These are default scenarios only, not every scenario supported by those scripts. They inject console records; the paste cases do not access the system clipboard. The filesystem picker wrapper writes its five PASS results to its report file, which was inspected.

Linux/macOS native interactive lifecycle, real terminal rendering, clipboard, IME and keyboard layouts remain unexecuted. POSIX interactive support is implemented but has not been validated on either platform. The requested 38-component public acceptance matrix, actual Windows terminal EOF beyond the injected Ctrl+Z record, and complete native platform coverage remain outstanding. None of these gaps is a pass.
