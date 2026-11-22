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

`dart test test/component_acceptance_matrix_test.dart --reporter expanded` ran 76 public-seam cases on Windows and reported all passed. Each of the following has exactly one rich and one linear case: TextInput, Password, Multiline, Autocomplete, TagInput, Confirm, Checkbox, Toggle, Select, Radio, MultiSelect, SearchSelect, CommandPalette, TimezoneSelect, TreeSelect, SortableSelect, Slider, RangeSlider, TimeInput, PathInput, FilePicker, DirectoryPicker, Keypress, KeyChordInput, NumberInput, PortInput, IPAddressInput, URLInput, EmailInput, ColorInput, MaskedInput, DurationInput, DateInput, CronInput, Text, Progress, Spinner and MultiSpinner. Text's public `present` method has no mode parameter, so its two named cases exercise the same mode-independent presentation rather than different renderers. Other cases use `PromptMode` with public scripted input or feedback output. These are task/outcome examples, not exhaustive contract coverage or native terminal proof. `dart analyze` reported no issues and the full `dart test --reporter compact` suite reported 549 passed after this increment.

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

Linux/macOS native interactive lifecycle, real terminal rendering, clipboard, IME and keyboard layouts remain unexecuted. POSIX interactive support is implemented but has not been validated on either platform. The 38-component public acceptance matrix is recorded in the increment above; actual Windows terminal EOF beyond the injected Ctrl+Z record and complete native platform coverage remain outstanding. None of these gaps is a pass.

## Native reruns after the plain-ASCII and review-retention fixes

At integration revision `2857fb7` `dart analyze` reported no issues and `dart test --reporter compact` reported `550: All tests passed!`. That increment renders Multiline tabs as `\t` with escaped backslashes instead of a non-ASCII glyph, and returns a cancelled cron preview to the retained-expression review instead of ending the prompt. The affected paths were re-checked natively:

| Check | Observed cases |
| --- | --- |
| `multiline_windows` | rich PASS, result `61,a,62` |
| `cron_input_windows` | rich and linear PASS, result `* * * * *`; `rich-cancel` and `linear-cancel` PASS, result `cancelled` |
| `text_input_windows` | default repeat scenario PASS, result `alpha,alpha` |
| `url_email_native_checks` | URL and email each PASS in rich and linear |

Every case above ends with the input mode, output mode and cursor state it started from (`503:7:25:1`) and every wrapper exited 0. The rich URL and email cases never leave the initial input mode mid-session; the other cases record `496:7:25:1` while the prompt owns the console. These remain injected-console-record checks: they are not real keyboard, clipboard, IME, rendering or NVDA evidence, and the POSIX runs stay unexecuted.

## Native reruns for the TERM=dumb and signal-interruption increment

With the capability and signal changes in place, the TextInput native harness ran
every scenario on Windows: `rich`, `escape`, `interrupt`, `eof`, `error`,
`repeat`, `concurrent`, `redirected`, `stdout`, `paste`, `unicode`, and the new
`dumb-auto` and `dumb-rich` cases. All exited 0 and ended with the console state
they started from (`503:7:25:1`). `dumb-rich` returned `unavailable:Rich
interaction unavailable on the selected output; use linear or automatic mode.`
without entering raw input mode; `dumb-auto` stayed linear and returned `alpha`.

One earlier `rich` run returned `alphac` and exited 1; three immediate repeats
returned `alpha` and passed. That single failure is recorded rather than silently
dropped: it did not reproduce, and its cause is unexplained. The scenario is
reported only for the repeats actually observed.

`test/posix_terminal_pty.py` now also covers Ctrl+C delivered as `SIGINT` and
`TERM=dumb` in automatic and explicit-rich modes, and the POSIX reader watches
for SIGINT instead of relying on the input byte alone. Those cases have not been
executed: no Linux or macOS host, WSL distribution, container runtime or Git
remote is available here. Only `python -m py_compile test/posix_terminal_pty.py`
was run, which is a syntax check and not a pass. Real rendering, clipboard, IME,
keyboard layouts and NVDA remain unverified.
