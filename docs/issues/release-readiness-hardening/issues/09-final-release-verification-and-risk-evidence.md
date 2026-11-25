# 09 Final verification battery and remaining-risk evidence

Status: resolved

**Blocked by:** [01](01-input-event-crlf-and-multiline-finish.md), [02](02-conpty-staging-and-diagnostics.md), [03](03-native-f1-help-contracts.md), [04](04-public-native-fixture-routes.md), [05](05-ci-public-native-lifecycle-coverage.md), [06](06-deterministic-tests-and-environment-honesty.md), [07](07-generated-files-formatting-and-public-api-ci.md), [08](08-prerelease-docs-version-and-release-evidence.md)

**What to build:** Run and record the complete release-verification battery on the integration branch: formatting, static analysis, documentation links, tracker integrity, full Dart tests, generated-file byte verification, external public API positive/negative checks, corrected Windows native scenarios, and available POSIX/native workflow evidence. Using the new diagnostics, investigate the intermittent framed-multiline paste failure and record either a fixed root cause or a bounded environmental explanation with remaining risk explicit. Confirm documentation/version agreement, absence of stable/accessibility overclaims, and that independent interaction and colour gates remain ready-for-human. Resolve any integration regressions uncovered by the battery. See the [spec](../spec.md), especially “Verification sequence for the implementing agent”.

## Acceptance criteria

- [x] Formatting, analyzer, documentation-link checker, tracker checker, full Dart test suite, generated-file checker, and external public API checker all pass on the integration branch or explicit platform limits are recorded.
- [x] Corrected Windows native TextInput and multiline ConPTY scenarios pass through public or explicitly named compatibility routes as applicable; POSIX evidence/status is accurately recorded.
- [x] The intermittent framed-multiline failure is either root-caused/fixed or documented as a bounded environmental risk using captured diagnostics.
- [x] Prerelease documentation/version agree and human interaction/colour gates remain explicit blockers.
- [x] Final verification evidence is recorded in this ticket’s Answer with exact commands and outcomes.

## Comments

## Answer

Verification ran on this worktree/branch (`release-readiness/09-final-verification`),
based on integration tip `5234505` (`integration/release-readiness-hardening`). The
integration branch did not advance during the work, so no merge was needed. Commits:

- `ec44431` tracker claim
- `ac4586d` remove accidental `fix_cron.py` migration-script residue (integration
  cleanup; the file was a one-shot edit script committed unintentionally by ticket 06
  in `9625f43` and is not referenced anywhere)
- `4487901` fix(input): wait out fractured escape sequences (framed-multiline root cause)
- `6a403df` test(multiline): component-level fractured-paste regression proof

### 1. Local verification battery (final code, host `windows_x64`, Dart SDK 3.13.2)

| check | command | outcome |
| --- | --- | --- |
| formatting | `dart format --output=none --set-exit-if-changed .` | PASS, 898 files, 0 changed |
| analyzer | `dart analyze` | PASS, no issues found |
| doc links | `dart run tool/check_doc_links.dart` | PASS, 1256 relative links in 283 Markdown files |
| tracker | `dart run tool/check_issue_tracker.dart` | PASS, 201 Git-backed tracker files |
| full tests | `dart test` | PASS, 5706 tests passed, 4 explicitly skipped (`requires a POSIX/macOS/Linux host`), 0 failures |
| generated diffs | `python tool/check_generated_diffs.py` | PASS, `generated diff check: ok (43 targets)` |
| public API | `dart run tool/check_public_api.dart` | PASS, positive fixture compiles as an external package; every negative case rejected with its expected diagnostic code (`negative public API inventory: ok`) |
| PowerShell parser | `System.Management.Automation.Language.Parser::ParseFile` on `test/text_input_windows.ps1` and `test/multiline_conpty_windows.ps1` | PASS, 0 parse errors each |
| workflow YAML | Python `yaml.safe_load` on `.github/workflows/platform-regression.yml` | PASS, parses cleanly |

Checks that mutate or analyze fixture files ran serially, never concurrently with the
analyzer or each other. The full battery ran once before the input-decoder fix (all
green) and again after it (all green; numbers above are the post-fix final runs).

### 2. Windows native coverage (workflow-equivalent public matrix)

Driven exactly as `.github/workflows/platform-regression.yml` does: every public
scenario through `powershell -NoProfile -ExecutionPolicy Bypass -File
test/text_input_windows.ps1 -Scenario <name> -PublicApi -Report <unique-path>`, plus
compatibility `concurrent` without `-PublicApi` labeled as compatibility coverage.
Unique report paths under `verification-artifacts/native/` (preserved copies at
`C:\Users\bvlou\projects\prompty-agent-notes\release-readiness-hardening\verification-09\native\`).

Post-fix full matrix result: **all 23 scenarios PASS, 0 failures**:

- public: `rich`, `linear-cursor`, `linear-long`, `help-text-linear`, `help-text-rich`,
  `help-password-linear`, `help-password-rich`, `help-password-interrupt-linear`,
  `help-text-eof-rich`, `redirected`, `stdout`, `dumb-auto`, `dumb-rich`, `escape`,
  `interrupt`, `eof`, `error`, `repeat`, `paste`, `unicode`, `session-retire`, `resize`
- compatibility (internal route, not public lifecycle evidence): `concurrent`

Every report carries console-restoration evidence, e.g.
`state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`: input mode, output mode, cursor size
and cursor visibility return to the exact pre-launch baseline after the prompt exits
(`dumb-rich` correctly never leaves baseline: rich interaction is refused on a dumb
terminal). Help scenarios verify F1 modal help, non-nesting, modal noise swallowing,
secret non-disclosure and Escape restoration; `native/matrix-summary.txt` records one
line per scenario.

### 3. Multiline ConPTY harness

`powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1
-ArtifactRoot <root>` — all 8 scenarios PASS both before and after the decoder fix:
`framed-command`, `typed-command`, `framed-multiline`, `editing`, `f1-modal-help`,
`unassigned-function-key`, `application-navigation`, `rich-enter-ctrl-j`. Successful
diagnostic artifacts were cleaned by the harness as designed.

### 4. Intermittent framed-multiline failure: root-caused and fixed

Flake probe (pre-fix): 12 consecutive `framed-multiline` runs, one retained artifact
root per run — 12/12 PASS, no failure reproduced, no diagnostic artifacts retained
(`verification-09/flake-probe/probe-summary.txt`). The historical failure predates the
ticket-02 diagnostics, so no captured failure artifact existed anywhere.

Rather than stopping at non-reproduction, the decoder was audited for timing-dependent
paste paths. Exactly one exists: `SharedTerminalReader` applied the 80 ms
escape-disambiguation flush not only to a lone `\x1b` but to any incomplete CSI/SS3
prefix. A bracketed-paste opener `\x1b[200~` split across input chunks with a gap
beyond 80 ms (normal for pseudoconsole/pty/ssh transports under scheduling pressure)
was corrupted into a bare Escape plus ordinary typed text — turning framed paste
content into key gestures, including line-ending gestures that submit or cancel
incorrectly. This matches the intermittent framed-multiline signature precisely and is
the only chunk-timing-sensitive paste path in the reader.

Deterministic reproduction (pre-fix): feeding `\x1b[20` then, 150 ms later,
`0~x\r\n/cancel\x1b[201~` emitted 16 fractured keys (`1b`, `5b`, `32`, `30`, `30`,
`7e`, ...) instead of one atomic paste key. Failing evidence first:

- new reader regression test `framed paste remains atomic when the opener fractures
  beyond the escape disambiguation window` — FAILED pre-fix, passes post-fix;
- new component regression test `framed paste split beyond the escape window stays
  literal data` in `test/multiline_test.dart` — verified failing pre-fix
  (`dart test test/multiline_test.dart -n "framed paste split"` -> exit 1, `[E]`) by
  temporarily restoring the pre-fix decoder, then passing with the fix.

Fix (`4487901`): incomplete CSI/SS3 sequences are bytes in transit, never keypresses —
the reader waits for completion instead of flushing them as a bare Escape. The
lone-byte `\x1b` disambiguation window is unchanged (pinned by the new `a bare escape
still flushes after the disambiguation window` test). The traded-away ambiguity — a
user pressing Escape and then typing `[` or `O` within the window — is byte-for-byte
indistinguishable from a sequence in any terminal input stack and is documented in the
code comment; CHANGELOG.md records the behavior change. Post-fix probes: 8/8
consecutive `framed-multiline` ConPTY runs PASS (`verification-09/flake-probe-postfix`);
full ConPTY harness 8/8 PASS; full dart suite 5706 PASS.

Honest residual risk: the historical flake was never captured with diagnostics, so the
fracture mechanism cannot be proven to be the only cause; it is the only
timing-sensitive paste path in the decoder, it reproduced the failure signature
deterministically, and it is now eliminated with regression coverage. If a second
cause exists, the new harness diagnostics will retain artifacts on any recurrence.

### 5. Separately observed native-probe flake (bounded, documented, not the paste defect)

One post-fix spot-check run of `help-text-linear` failed once:
`text input public help-text-linear FAIL timed out waiting for the left-arrow caret
state: 7:5:> alphat` (preserved at `verification-09/native-postfix/`). Investigation:

- the Windows console input path delivers complete key sequences (`\x1b[D` etc.) as
  single stream elements, so the byte-stream decoder change cannot affect it;
- 12/12 consecutive standalone post-fix reruns passed, and the full post-fix matrix
  run passed it as well (1 failure in 13 post-fix attempts, 0 in the pre-fix matrix);
- the failing run orphaned its dart grandchild (found and killed during cleanup): the
  console probe kills the outer powershell but cannot reap the grandchild of a
  never-completing scenario — a bounded harness-cleanup limitation, now evidenced;
- the observed row text `alphat` is not a valid settled frame for this scenario, which
  implicates console-read/repaint timing inside the probe rather than lost input, but
  the evidence cannot fully exclude a genuine startup-phase input race.

Bounded risk statement: rare (order 1-in-13 or lower) probe-side timing flake in one
help scenario, no product defect evidenced, no relation to the paste fracture.

### 6. POSIX / Linux / macOS status

This Windows host cannot execute POSIX PTY natively: no Docker (`docker` not found),
no WSL distributions installed, and installing infrastructure is out of scope. The
POSIX PTY harness (`test/posix_terminal_pty.py`) was inspected: every scenario
launches the fixture `public-` route and reports `public-route/<behavior>`, and the CI
workflow provisions the Linux locale fixture. The 4 skipped dart tests on Windows are
explicit platform declarations.

Final POSIX execution evidence now comes from GitHub Actions run
[45721224547](https://github.com/louiss0/trelis/actions/runs/45721224547) on pushed
candidate `aead39e90f3ad4e8fa2740e0ac0972ad42d4f4d6`: both
`posix-native (ubuntu-latest)` and `posix-native (macos-latest)` passed the public
POSIX PTY native lifecycle. The Dart matrix also passed on Ubuntu, macOS, and Windows.
The original no-push limitation was true when this answer was first written and is
superseded by the final CI closure supplement below.

### 7. Documentation/version consistency

- `pubspec.yaml` is `1.0.0-dev.1`; CHANGELOG top entry agrees and declares the API
  unstable with the human gates open; no stray stable `1.0.0` version references.
- README examples use the public theme-instance API (`RailTheme(io: ...)` plus
  parameterless `prompt()`); release-status and accessibility sections explicitly make
  no stable, accessibility, screen-reader or colour-quality claims.
- Publish dry-run evidence at `assets/evidence/release-readiness/publish-dry-run.md`
  records both accepted warnings (exact `termunicode` pin, docs-directory convention)
  as tradeoffs, evidence only.
- Independent human gates verified still open: adaptive-theme-presentation tickets 37
  and 38 (reader evidence) and 41/42 (colour/interaction release gates) are all
  `ready-for-human`.

### 8. Processes and artifacts

One orphaned dart grandchild from the single failing probe run was found and killed;
no other probe children remain. Artifact copies:
`C:\Users\bvlou\projects\prompty-agent-notes\release-readiness-hardening\verification-09\`
(`native/` matrix reports plus summary, `native-postfix/` spot-check reports including
the one preserved FAIL report, `flake-probe/probe-summary.txt`, `htl-probe/` 12 PASS
reports).

### Review-fix supplement — 2026-11-25

Review-fix work ran on `release-readiness/review-fix`, based directly on local
integration tip `109354b` (`integration/release-readiness-hardening`). The local
integration branch was still at that commit when checked, so no merge was needed.
`git fetch origin integration/release-readiness-hardening` reported that the remote
ref does not exist, so there was no newer remote integration tip to merge. Nothing
was pushed. Implementation commits:

- `5eec709` test(native): make Windows harness lifecycles deterministic
- `7a4d27a` test(native): share text input fixture support
- `70a893d` test(posix): cover redirected public text output
- `b432262` build: enforce LF generated palette output
- `3126778` test(api): reject hidden legacy input sources

#### Standards-axis corrections

- Fixed second-scale sleeps were replaced in the Windows native PowerShell
  harnesses by explicit child `*.ready` / `*.release` handshakes and bounded
  polling for observable console state. Millisecond sleeps remain only as bounded
  poll intervals. `terminal_probe_windows.ps1` additionally waits for the actual
  `probe 1>`/`probe 2>` screen paints after learning that mode acquisition alone
  precedes input readiness.
- Probe cleanup now writes the release file, detaches, gives the child a bounded
  exit opportunity, and uses `taskkill.exe /T /F` before any last-resort
  `Stop-Process`, so the PowerShell/Dart process tree rather than only the outer
  launcher is reaped. ConPTY already uses a kill-on-close job object.
- `text_input_windows.ps1` is table-driven: behavior, input driver, expected
  result, route differences and cleanup contract live together. Failure reports
  carry phase, elapsed/phase elapsed time, result/stderr file content, done and
  trigger state, dart/outer exit status, console before/during/after state,
  terminal transcript and artifact path. Reports explicitly label `public` versus
  `compatibility` routes.
- The duplicated native fixture support for trigger waits, paint observation and
  failing output/session-retirement plumbing is shared in
  `test/support/text_input_native_fixture.dart` by the compatibility and public
  fixture routes.
- The workflow now runs `python tool/check_native_harness_determinism.py` and the
  multiline ConPTY harness with workspace-local `conpty-artifacts`; successful
  scenario directories are still removed, while a failure upload step retains any
  remaining diagnostic artifacts with `if-no-files-found: ignore`.

#### Spec-axis corrections

- `test/posix_terminal_pty.py` now covers public stderr redirection through a real
  non-terminal file and public stdout selection where prompt output and the final
  machine-readable result share one pipe. It records redirected stderr bytes in
  failure artifacts. This host cannot execute the POSIX harness (`import fcntl` is
  unavailable on Windows), so the evidence is static/compile evidence plus CI
  workflow wiring only, not POSIX runtime evidence.
- Palette generators write through `tool/lf_output.py`; palette check mode and the
  generated-diff checker compare bytes, the checker covers all three palette
  outputs, and `.gitattributes` pins `lib/src/*_palettes.g.dart` to LF.
- The external public API checker now has explicit hidden-symbol negatives for
  `PromptSource` and `ScriptedInput`; both were rejected with
  `UNDEFINED_IDENTIFIER` in the final run.

#### Final local verification battery

| check | exact command | outcome |
| --- | --- | --- |
| formatting | `dart format --output=none --set-exit-if-changed .` | PASS, 899 files, 0 changed |
| analyzer | `dart analyze` | PASS, no issues found |
| documentation links | `dart run tool/check_doc_links.dart` | PASS, 1256 relative links in 283 Markdown files |
| tracker integrity | `dart run tool/check_issue_tracker.dart` | PASS, 201 Git-backed tracker files |
| full Dart tests | `dart test` | PASS, 5706 tests passed, 4 explicit POSIX/platform skips, 0 failures |
| generated files | `python tool/check_generated_diffs.py` | PASS, `generated diff check: ok (46 targets)` |
| harness determinism guard | `python tool/check_native_harness_determinism.py` | PASS, `native harness determinism check: ok` |
| external public API | `dart run tool/check_public_api.dart` | PASS, positive fixture compiles and all negatives reject; ends `negative public API inventory: ok` |
| PowerShell syntax | `System.Management.Automation.Language.Parser::ParseFile` over `test/*.ps1` | PASS, `powershell parse: ok` |
| Python syntax | `python -m py_compile test/posix_terminal_pty.py tool/check_native_harness_determinism.py tool/check_generated_diffs.py tool/lf_output.py` | PASS |
| workflow YAML | Python `yaml.safe_load` on `.github/workflows/platform-regression.yml` | PASS |

Windows native evidence:

- The workflow-equivalent TextInput matrix passed **23/23**: all 22 public
  scenarios (`rich` through `resize`, including redirected/stdout/dumb/help/
  session-retirement cases) plus explicitly labeled compatibility `concurrent`.
  Every report includes exact console restoration evidence, normally
  `state=503:7:25:1 -> 1008:7:25:1 -> 503:7:25:1`; redirected/stdout/dumb
  variants truthfully show the applicable linear/output state. Preserved copies:
  `C:\Users\bvlou\projects\prompty-agent-notes\release-readiness-hardening\review-fix\native\`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1 -ArtifactRoot "conpty-artifacts"`
  passed **8/8** (`framed-command`, `typed-command`, `framed-multiline`,
  `editing`, `f1-modal-help`, `unassigned-function-key`,
  `application-navigation`, `rich-enter-ctrl-j`) and cleaned successful artifacts;
  the workspace artifact root was absent afterward as designed.
- Focused lifecycle sanity checks after the harness rework passed:
  `terminal_probe_windows.ps1 -Scenario submit` produced
  `submit PASS results=submit:ok,submit:ok`, and `feedback_windows.ps1` produced
  `feedback native rich narrow console PASS input mode 503 -> 503`.
- Post-matrix process inspection found `no native probe processes` among
  PowerShell/Dart/cmd processes matching the native probe command lines.

Harness timing issue found and corrected during the matrix: an early run of the
reworked harness failed public `eof` once with `unexpected result: alpha` because
console acquisition can be observed before the first complete prompt paint, making
control-key-only input timing-sensitive. No product code changed. The harness now
waits for the editable default paint before EOF/Escape/Ctrl+C injection; focused
evidence was 5/5 consecutive public EOF passes, followed by the final 23/23 matrix
pass. This is a harness-coordination fix, not proof of a product defect.

#### Remaining risk at review-fix completion

These bullets were true before the post-review push and are superseded by the final
CI closure supplement below:

- POSIX/Linux/macOS runtime evidence was unavailable from this Windows host. The
  POSIX harness compiled under Python and the workflow wiring was present, but no
  POSIX execution was yet claimed.
- GitHub Actions greenness was unverified because nothing had been pushed and no CI
  run had been monitored. Local evidence included workflow YAML parsing and
  workflow-equivalent Windows harness execution only.
- The historical orphan-grandchild limitation is narrowed by tree/job cleanup, but
  Windows process evidence is necessarily host-local. If a future rare failure
  precedes cleanup abnormally, the retained diagnostic files now include enough
  process and phase state to bound it rather than silently losing it.

### Final CI closure supplement - 2026-11-25

After the review-fix merge, the integration branch was pushed and the complete
platform-regression workflow was iterated to green. Final green run:
[45721224547](https://github.com/louiss0/trelis/actions/runs/45721224547), candidate
commit `aead39e90f3ad4e8fa2740e0ac0972ad42d4f4d6`, conclusion `success` in all six
jobs:

- `dart (windows-latest)` - PASS
- `dart (ubuntu-latest)` - PASS
- `dart (macos-latest)` - PASS
- `windows-native` - PASS, including the public TextInput native lifecycle matrix,
  explicitly labeled compatibility coverage, and the multiline ConPTY lifecycle
- `posix-native (ubuntu-latest)` - PASS, public POSIX PTY native lifecycle
- `posix-native (macos-latest)` - PASS, public POSIX PTY native lifecycle

The workflow iteration exposed and fixed two genuine defects rather than hiding them:

1. Linux numeric locale FFI handling was incorrect. CI first exposed a crash/failure
   in the Linux-only numeric-locale test; `69c2f6e` corrected the Linux `lconv`
   struct layout and `f1c0fb5` passed a complete glibc locale-category mask to
   `newlocale`. The final Ubuntu Dart job passed, including the non-C `LC_NUMERIC`
   precedence test.
2. The Windows ThaiBuddhistCalendar modern-vector test could be starved by suite
   contention beside the 400-year PowerShell oracle sweep. `aead39e` gives that test
   the same bounded two-minute failure window as the cycle test rather than leaving
   it to runner scheduling. The final Windows Dart job passed.

No acceptance criterion remains blocked on POSIX or GitHub Actions evidence. The
remaining honest limitation is narrower: CI evidence is hosted-runner evidence, not a
proof for every terminal emulator, Windows console host, or locale image; the retained
native diagnostics are the mechanism for investigating future environment-specific
failures.

