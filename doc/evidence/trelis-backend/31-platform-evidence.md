# Backend platform evidence — ticket 31

## Verdict: automated cross-platform matrix passing at one revision

Accepted source revision: `65a7940` on
`ticket/backend-31-platform-evidence`, whose merge base is integration
`29a7286` (identical to `origin/main` at the time of the run).
Workflow: `.github/workflows/platform-regression.yml`, Dart 3.13.2.

Run [43618507564](https://github.com/louiss0/trelis/actions/runs/43618507564)
completed `success` for every job:

| Job | Runner image | Result |
| --- | --- | --- |
| dart (windows-latest) | `windows-2025-vs2026` | pass, 926 tests |
| dart (ubuntu-latest) | `ubuntu-26.04` | pass, 926 tests |
| dart (macos-latest) | `macos-26-arm64` | pass, 926 tests |
| posix-native (ubuntu-latest) | `ubuntu-26.04` | pass, ten PTY scenarios |
| posix-native (macos-latest) | `macos-26-arm64` | pass, ten PTY scenarios |
| windows-native | `windows-2025-vs2026` | pass, 17 TextInput scenarios + six ConPTY cases |

Each Dart job also reported `Formatted 150 files (0 changed)`,
`No issues found!` from `dart analyze`, and
`Checked 155 relative links in 55 Markdown files.`
Every POSIX stage reported `Dart VM version` matching the pinned SDK from
`/opt/hostedtoolcache/dart/3.13.2/x64` (Ubuntu),
`/Users/runner/hostedtoolcache/dart/3.13.2/arm64` (macOS).

The POSIX jobs print one line per scenario. Both reported
`rich: PASS (alpha)`, `escape: PASS (cancel)`, `interrupt: PASS (interrupt)`,
`signal: PASS (interrupt)`, `eof: PASS (eof)`, `error: PASS (alpha)`,
`repeat: PASS (alpha,alpha)`, `session-retire: PASS (retired)`,
`dumb-auto: PASS (alpha)`, and
`dumb-rich: PASS (unavailable:Rich interaction unavailable on the selected
output; use linear or automatic mode.)`. Each returning scenario compares the
terminal attributes captured before the run with the ones left afterwards.

The Windows native job printed the console state before, during and after
every scenario (`503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`, `496:7:25:1` for
the 496 state) and reported `framed-command`, `typed-command`,
`framed-multiline`, `editing`, `function-key` and `application-navigation`
PASS through the pseudoconsole.

## Failures this revision closes

Run [43614138132](https://github.com/louiss0/trelis/actions/runs/43614138132)
at integration `29a7286` failed three jobs. Each failure was reproduced from
its log, explained, and turned into a check at the level where the defect
lived; none was waived by a retry.

**macOS Dart — `system default resolves effective numeric settings`.**
`_macOSNumericConvention` returned null, so `NumberInput` reported
`Unavailable`. Run [43617914019](https://github.com/louiss0/trelis/actions/runs/43617914019)
carried a temporary probe that printed what the resolver actually reads on
the runner: `locale=en_US`, `decimalSeparator .`, `groupingSeparator ,`,
`minusSign -`, `negativeFormat #,##0.###`, `negativePrefix -`, empty
`negativeSuffix`, `groupingSize 3`, `secondaryGroupingSize 0`,
`usesGroupingSeparator 1`, digits `0`–`9`. The decimal style returns the
positive shape as the negative format and keeps the sign in the affixes, so
the format string never matched a sign placement and every macOS system
convention was discarded. `65a7940` classifies the placement from
`negativePrefix`/`negativeSuffix` and the probe was removed in the same
commit. The earlier unrecognised `negativeSign` selector this ticket already
repaired aborted the process (exit 134) instead of reporting a result.

**macOS native PTY — `rich: terminal attributes not restored`.**
The restored local flags read `536872395` against `1483` before the session:
a difference of exactly `PENDIN` (`0x20000000`). `848b403` excludes only
that bit, and only on Darwin, from the restoration comparison. The
application is not at fault: in xnu's `bsd/kern/tty.c` the `tcsetattr` path
sets `PENDIN` when the request re-enables `ICANON` (raw → canonical, which is
exactly a prompt restoring the state it received) and then stores
`tp->t_lflag = t->c_lflag | ISSET(tp->t_lflag, PENDIN)`, so writing the
captured bytes back cannot clear it; the kernel clears it on the next input
read or flush. Linux has no equivalent flag, which is why only the macOS job
showed it. No other flag is tolerated, and a changed control character,
speed or input/output flag still fails the comparison.

**Ubuntu native PTY — `signal: exit=-2, stdout=b''`.**
Two causes, both in the harness. `dart run` does not necessarily run the
script in the launched process: on the SDK used here the launcher starts a
`dartvm` child (measured on Windows as `dart.exe → dartvm.exe`), so
`os.kill(process.pid, SIGINT)` killed the launcher while the prompt never
received the signal. The prompt also paints its opening frame before it
subscribes to input, and that subscription is where the native reader
installs its `SIGINT` watcher, so signalling straight after the first frame
can land in the window before the watcher exists. `76da878` gives the child
its own process group, interrupts the group the way a terminal does, types
and waits for the echoed draft so the reader is provably live, and requires
the application's own printed result — a process that failed to handle the
signal prints nothing. The harness also now reports the accumulated terminal
output instead of the buffer cleared just before the failure, and stops the
whole group so no VM child survives into the next scenario.

## Scope and limits of this evidence

- The captures are CI runner sessions. No physical Linux/macOS machine, human
  confirmation or local GUI check was used, as B-PLATFORM requires.
- macOS and Ubuntu coverage is the shared PTY harness over the public
  `TextInput` native path plus the Dart suite. Component-specific native
  wrappers (`test/*_windows.ps1`, `test/*_native_checks.ps1`) still run only on
  Windows; the POSIX matrix is not a per-component native matrix.
- The macOS convention evidence covers the `en_US` runner locale only. Other
  locales, and any locale whose negative affixes do not match `minusSign`, are
  reported as unavailable rather than guessed at.
- `test/number_input_native_checks.ps1` was executed locally and is not green:
  its preference-change branch fails on this machine, with two different
  symptom messages across attempts, both with and without this branch's Dart
  change (`number input FAIL unexpected result: 1234,5`, and
  `number input FAIL probe process did not exit`). That wrapper rewrites
  `HKCU:\Control Panel\International` for the duration of the run; it restored
  the decimal, operator, grouping and sign values it changed, and the empty
  `iNeg` value it created was removed afterwards, with the Windows system
  convention test still passing. The wrapper is not part of the CI workflow,
  the failures are unrelated to the macOS resolver, and this report does not
  count them as passing.
- Windows native evidence uses injected console records and a pseudoconsole;
  it is not real keyboard, clipboard, IME, rendering or NVDA evidence. The
  agent GUI/NVDA evidence for B-GUI remains a separate, still pending gate.
- A configured workflow or a local probe is not acceptance: the run above is
  the execution, at the revision named first.

## Previously recorded local evidence

The earlier local Windows baseline in this file (revision `23aff9b` and the
`de7ed84` runtime baseline, 926 tests, 17 TextInput scenarios, six ConPTY
cases, the harness corrections for the password canary and the long-line
overflow marker) still describes what was observed locally; it is superseded
as platform evidence by the CI run above and is kept for the local detail it
records.

Ticket 31 additionally needs B-GUI visible-GUI/NVDA evidence and the final
B-GATE audit; neither is claimed here.
