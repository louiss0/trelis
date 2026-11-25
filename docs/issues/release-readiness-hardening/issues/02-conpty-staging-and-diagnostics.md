# 02 ConPTY staged input, diagnostics, artifacts, and cleanup

Status: claimed

**Blocked by:** none

**What to build:** Upgrade the Windows ConPTY/native harness infrastructure so interaction can be staged against observable screen or readiness states instead of blind fixed writes. Failure reporting must combine scenario, phase, elapsed wait, child exit status when available, expected result, captured terminal transcript, result-file presence, and artifact location. Startup readiness, interaction deadlines, process completion, and result-file collection are distinct phases. Retain artifacts only on failure, clean them on success, and clean child processes plus pseudoconsole handles on every path. This is harness infrastructure only, not a production seam. See the [spec](../spec.md), especially “F1 native scenarios and ConPTY diagnostics”.

## Acceptance criteria

- [ ] ConPTY harness stages input only after bounded observable readiness/screen conditions; fixed post-start blind writes are removed from corrected scenarios.
- [ ] Failures identify distinct startup, interaction, process-exit, and result-file phases without losing the original diagnostic behind a missing result file.
- [ ] Failure artifacts contain transcript and state needed for diagnosis; success paths remove diagnostic noise.
- [ ] All child processes, handles, and pseudoconsole resources are cleaned up on success and failure.
- [ ] Focused native harness tests or scripted probes demonstrate both success cleanup and failure artifact retention/diagnostics.

## Comments
