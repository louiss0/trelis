# 02 ConPTY staged input, diagnostics, artifacts, and cleanup

Status: resolved

**Blocked by:** none

**What to build:** Upgrade the Windows ConPTY/native harness infrastructure so interaction can be staged against observable screen or readiness states instead of blind fixed writes. Failure reporting must combine scenario, phase, elapsed wait, child exit status when available, expected result, captured terminal transcript, result-file presence, and artifact location. Startup readiness, interaction deadlines, process completion, and result-file collection are distinct phases. Retain artifacts only on failure, clean them on success, and clean child processes plus pseudoconsole handles on every path. This is harness infrastructure only, not a production seam. See the [spec](../spec.md), especially “F1 native scenarios and ConPTY diagnostics”.

## Acceptance criteria

- [x] ConPTY harness stages input only after bounded observable readiness/screen conditions; fixed post-start blind writes are removed from corrected scenarios.
- [x] Failures identify distinct startup, interaction, process-exit, and result-file phases without losing the original diagnostic behind a missing result file.
- [x] Failure artifacts contain transcript and state needed for diagnosis; success paths remove diagnostic noise.
- [x] All child processes, handles, and pseudoconsole resources are cleaned up on success and failure.
- [x] Focused native harness tests or scripted probes demonstrate both success cleanup and failure artifact retention/diagnostics.

## Comments

## Answer

Implemented the ConPTY harness infrastructure in `test/multiline_conpty_windows.ps1`:

- Added `MultilinePtyStage`/`MultilinePtyResult` staged input support. Each write is preceded by a bounded observable transcript condition; post-start conditions can require output appended since the preceding write. Startup, interaction, process-exit, and result-file collection are reported as distinct phases.
- Added structured diagnostics containing scenario, phase/stage, elapsed and wait time, child process exit state when available, Dart exit sidecar state when present, expected/actual result, result-file presence/content, input stages, artifact location, and the captured terminal transcript. Artifacts include `diagnostic.json`, `failure.txt`, `transcript.txt`, result output, and child sidecars.
- Failure artifact directories are retained; successful scenario directories are deleted, and the artifact root is removed only when empty so older failure evidence is not erased.
- The child helper now writes result, Dart exit-code, and child-error sidecars instead of letting a missing result file hide the original failure.
- ConPTY children are created suspended, assigned before resume to a kill-on-close job object, and terminated through that job on failure. Process/thread handles, pipe handles, pseudoconsole handles, the attribute list, and the drain task are cleaned in `finally` on every path.
- The harness is mode-parameterized and includes `rich-enter-ctrl-j`, which writes Enter and Ctrl+J as separate stages after observing `one` painted and then `Line 2:` painted. This is native coverage of the ticket-01 separate-event contract; no F1 scenario semantics or public fixture routes were converted here.

Evidence and commands:

- `powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1 -Scenario rich-enter-ctrl-j -ArtifactRoot C:\Users\bvlou\AppData\Local\Temp\mct-postmerge` — PASS, exit 0; the artifact root was absent afterward, demonstrating success cleanup.
- `powershell -NoProfile -ExecutionPolicy Bypass -File test/multiline_conpty_windows.ps1 -ArtifactRoot C:\Users\bvlou\AppData\Local\Temp\mct-full` — six scenarios passed (`framed-command`, `typed-command`, `framed-multiline`, `editing`, `application-navigation`, `rich-enter-ctrl-j`). The pre-existing `function-key` contract failed as expected for ticket 03 because F1 opens modal help and the current scenario never dismisses it; the harness exited 1 only after running the remaining scenarios.
- The retained `function-key` artifact at `C:\Users\bvlou\AppData\Local\Temp\mct-full\function-key-877d0f44c7194f78aed31c31b75709e9` contained the transcript and structured state: `phase=interaction`, `stage=ordinary-input-painted`, elapsed/wait times, unavailable child exit status, expected result, `resultFilePresent=false`, input stages, and artifact paths.
- The failed outer harness process id `16856` was absent when checked afterward, demonstrating process cleanup on the failure path.
- PowerShell parser validation passed with `powershell syntax OK`. `PSScriptAnalyzer` is not installed on this host, so no analyzer run was available.
