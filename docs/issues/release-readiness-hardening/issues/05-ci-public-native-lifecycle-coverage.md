# 05 Windows and POSIX CI public native lifecycle coverage

Status: resolved

**Blocked by:** [02](02-conpty-staging-and-diagnostics.md), [04](04-public-native-fixture-routes.md)

**What to build:** Switch Windows release scenarios to the public-route fixture behavior and make POSIX PTY scenarios invoke explicitly public scenario names. Scenario output names identify both route and behavior. Any remaining legacy compatibility execution is labeled compatibility coverage and is not counted as public lifecycle evidence. Keep native coverage focused on acquisition/restoration, input decoding, modal help, resize observation, output refusal, writer-failure retirement, and process-signal behavior rather than duplicating every component happy path. Update the platform regression workflow so Linux, macOS, and Windows evidence meaningfully exercises the exported route. See the [spec](../spec.md).

## Acceptance criteria

- [x] Windows native lifecycle release jobs exercise public theme-instance routes and are named accordingly.
- [x] POSIX PTY scenarios pass explicitly public scenario names on Linux and macOS.
- [x] Legacy compatibility execution, if retained, is explicitly labeled and excluded from public lifecycle evidence.
- [x] Workflow names, artifact names, and scenario output make route plus behavior clear.
- [x] Platform regression workflow syntax is valid and relevant local/native checks pass or platform limitations are explicitly recorded.


## Answer

Implemented in commit `a6c4ac8` on `release-readiness/05-ci-native`.

### What changed

- `.github/workflows/platform-regression.yml` — the Windows lifecycle loop now
  passes `-PublicApi` for every scenario, writes reports named
  `text-input-public-<behavior>.txt`, and covers the behavior-focused public
  set: acquisition/restoration (`repeat`, `session-retire`), input decoding
  (`paste`, `unicode`, linear cursor/long-line editing), modal help
  (`help-*`), resize observation, output refusal/redirection (`dumb-auto`,
  `dumb-rich`, `redirected`, `stdout`), and cancellation/interruption/EOF/
  validation outcomes. `concurrent` remains as a separate step explicitly
  named compatibility coverage over the internal route — it is not counted as
  public lifecycle evidence. The multiline ConPTY step is labeled as the
  compatibility route. Both native jobs upload artifacts whose names identify
  platform, route and behavior.
- `test/posix_terminal_pty.py` — every scenario launches the explicit
  `public-<behavior>` fixture route; PASS lines are named
  `public-route/<behavior>`. `repeat` now completes all three public prompts
  (two reusable-prompt completions plus the second-theme reacquisition),
  `dumb-rich` expects the public refusal message, and `session-retire` passes
  a trigger file that the harness releases only after the acquired PTY state
  is observed, so writer-failure retirement cannot race acquisition. Failures
  are phase-annotated (startup, prompt paint, input staging, acquisition,
  process completion, result comparison, terminal restoration) with elapsed
  time, child exit status, stdout and terminal transcript persisted to
  `PTY_ARTIFACT_DIR` on failure only.
- `test/text_input_windows.ps1` — failure reports carry the `public` route
  marker like PASS reports do; `linear-cursor`/`linear-long` bounded-wait for
  the opening paint instead of racing it with a single read; a malformed
  `Test-Path ... -and` readiness condition introduced by the bounded-wait
  rewrite is fixed (it made every probe fail before evaluation).

### Evidence

- Windows public probes run locally on this Windows host, all PASS with
  console state restored (`503:7:25:1 -> ... -> 503:7:25:1`): `rich`,
  `linear-cursor` (`alphXa`), `linear-long` (300-digit draft with `X`
  insertion), `escape`, `interrupt`, `eof`, `error`, `repeat` (`alpha,alpha`),
  `session-retire` (`retired`), `resize` (60-digit draft), `redirected`,
  `stdout`, `dumb-auto`, `dumb-rich` (public refusal message), `paste`
  (`/cancel`), `unicode` (`1f600`). Compatibility `concurrent` PASS
  (`busy,alpha`). `linear-long` timed out once at the End-caret wait while
  two probe batches ran in parallel on this loaded host, then passed serially
  twice; the bounded waits rather than fixed sleeps remain the mechanism.
- Help scenarios: the harness still injects Ctrl+T, which the product no
  longer treats as help (F1-only since the key-gesture contract) — this is
  ticket 03's explicit scope and is unchanged here. A throwaway probe copy
  injecting real F1 (VK 0x70) showed the public help route opening help,
  keeping the secret hidden, and restoring the screen on dismissal; the
  remaining caret-capture race in the pre-help state capture belongs to the
  ticket 03 harness correction. Until ticket 03 merges, the `help-*` scenarios
  in the loop fail for that harness reason in both routes.
- POSIX PTY cannot execute on this Windows host (`os.name != 'posix'`).
  `python -m py_compile` passes and the logic was reviewed against the fixture
  routes; Linux/macOS execution evidence is deferred to the CI matrix, which
  is the recorded platform limitation.
- `platform-regression.yml` parses as valid YAML; the PowerShell parser
  accepts `test/text_input_windows.ps1`; `dart format
  --output=none --set-exit-if-changed .` is clean (898 files, 0 changed);
  `dart run tool/check_issue_tracker.dart` and `dart run
  tool/check_doc_links.dart` pass. No Dart sources changed.

## Comments
