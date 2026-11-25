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
workflow provisions the Linux locale fixture, but **no POSIX execution evidence exists
for this commit**. The 4 skipped dart tests are explicit platform declarations. The
platform regression workflow has not run in GitHub Actions: nothing was pushed (no
push authorization), so CI greenness is unverified; only local workflow-syntax
validation (YAML parse) and the workflow-equivalent local executions above exist.

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
