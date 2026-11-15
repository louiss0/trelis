# 33: Accept or block the backend evidence gate

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Open theme integration only when the refined backend backlog and current evidence actually satisfy every required acceptance condition.

**Blocked by:**
- [31: Execute the cross-platform automated and native matrix](31-platform-ci-native-evidence.md)
- [32: Exercise the backend through agent-operated Windows computer use](32-agent-windows-gui-evidence.md)

**Status:** blocked

**Acceptance reference:** [B-GATE](../../trelis-backend-implementation/spec.md#b-gate).

- [x] Audit every active backend ticket and normative B requirement at candidate revision `6bb265d9cc947bb854921508c4e8ddc33462af65` (local integration `75719dd` merged in); failures and pending/insufficient checks are explicit in [the acceptance audit](../../../doc/evidence/trelis-backend/backend-acceptance.md).
- [x] Require fresh all-platform CI/native and Windows agent-GUI evidence without adding a human or physical Linux/macOS gate. The fresh six-job matrix passed at the candidate; the GUI evidence remains insufficient for two checkpoints, so the gate is blocked.
- [x] Re-run affected evidence after changes and state limitations without treating readiness or planned coverage as a pass. Ticket 32's repaired evidence closes the concurrent-editor and modal-help defects; its deleted narrow/ASCII captures and its historical cleanup captures do not cover the newer `text_input` changes.
- [ ] Before resolving this ticket, mirror an actually accepted verdict and artifact pointers to the retained legacy gate reference; do not mark superseded layered work implemented. Not performed: no accepted verdict exists.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations in [the acceptance audit](../../../doc/evidence/trelis-backend/backend-acceptance.md); this publication is not implementation or a test pass.

## Claim

Claimed on `ticket/backend-33-evidence-gate` from integration revision
`135043d615392d3190eaf5f272dd6317485dd0a7`, then re-audited after integrating
local integration `75719dd`. The audit records only executed checks and
inspected artifacts; it does not implement backend behavior or start theme work.

## Result

**Blocked.** This second audit supersedes the earlier blocked verdict without
erasing it.

Accepted at the candidate: ticket 32's now-readable report and screenshots
11–17 show the draft and caret surviving concurrent `Spinner`/`Progress`/`Text`
writes (`Left`, `Left`, `X` produces `> alpXha`, and the run ends
`GUI-PROBE:accepted:alpXha;secret:accepted`), session-owned help rendering
paragraph breaks as real lines with the draft row cleared and repainted once on
dismissal, and no synthetic canary disclosure. The fresh six-job matrix at
`6bb265d` passed, as did 949 local tests, 67 focused GUI/session/help tests,
format, analysis and the 158-link doc check.

Still blocking: B-GUI has no artifact at this revision for narrow/idle resize or
for the ASCII/no-colour fallback. The repair deleted the only two captures that
carried those checkpoints (`02-narrow-modal-help.png`, `05-ascii.png`) without
re-running them, and `429526b` changed paragraph wrapping and draft-row
clearing, so B-GATE cannot carry the older captures forward. The
repeated/error/cancel/interruption captures remain at `7676a5f`, and
`08-error-recovery.png` does not visibly show a validation error. The installed
computer-use provider exposes no resize action, so the resize checkpoint is a
stated tooling limitation rather than a missing human check. Theme work and the
retained legacy gate remain blocked; see the linked audit for per-artifact
observations and the exact follow-up.
