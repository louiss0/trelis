# 33: Accept or block the backend evidence gate

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Open theme integration only when the refined backend backlog and current evidence actually satisfy every required acceptance condition.

**Blocked by:**
- [31: Execute the cross-platform automated and native matrix](31-platform-ci-native-evidence.md)
- [32: Exercise the backend through agent-operated Windows computer use](32-agent-windows-gui-evidence.md)

**Status:** resolved

**Acceptance reference:** [B-GATE](../../trelis-backend-implementation/spec.md#b-gate).

- [x] Audit every active backend ticket and normative B requirement at the accepted revision `81738e8a9e7278f872ab4b6c7c404c111607a4e2` (local integration `d9d8790` merged in); every requirement and task verdict, with its evidence pointer and limitation, is recorded in [the acceptance audit](../../../../doc/evidence/trelis-backend/backend-acceptance.md).
- [x] Require fresh all-platform CI/native and Windows agent-GUI evidence without adding a human or physical Linux/macOS gate. The fresh six-job matrix passed on a tree whose code is byte-identical to the accepted revision, and ticket 32 captured every named B-GUI checkpoint at that same code revision.
- [x] Re-run affected evidence after changes and state limitations without treating readiness or planned coverage as a pass. The previous audit's four follow-ups (visible ASCII run, narrow/idle resize capture, re-captured cleanups, corrected inventory) were all executed, and the local suite/native wrappers were re-run at the candidate.
- [x] Before resolving this ticket, mirror an actually accepted verdict and artifact pointers to the retained legacy gate reference; do not mark superseded layered work implemented. Mirrored into `issues/16-backend-evidence-gate.md` of the retained compatibility gate, with the finer 33-ticket plan named as the executed plan and no superseded task claimed as implemented.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations in [the acceptance audit](../../../../doc/evidence/trelis-backend/backend-acceptance.md); this publication is not implementation or a test pass.

## Comments

**Claim.** Claimed on `ticket/backend-33-evidence-gate` from integration revision
`135043d615392d3190eaf5f272dd6317485dd0a7`, re-audited after integrating local
integration `75719dd`, and re-audited again after integrating local integration
`d9d8790`. The audit records only executed checks and inspected artifacts; it
does not implement backend behavior or start theme work.

**Result: accepted.** This third audit supersedes the two blocked verdicts
without erasing them.

At the accepted revision every normative B requirement has an executed check and
an artifact pointer, and every tracker ticket 01–32 is resolved with evidence
re-run or re-captured at this one code revision (`git diff --stat b94efda
81738e8` lists only `doc/` and `docs/issues/` files, so the GUI captures, the probe
runs and the matrix describe the same backend):

- concurrent `Text`/`Spinner`/`Progress` writes preserve the draft and caret
  (`Left`, `Left`, `X` produces `> alpXha`; the run ends
  `GUI-PROBE:accepted:alpXha;secret:accepted`) with no canary disclosure;
- session-owned help renders paragraph breaks as real lines, clears the draft
  row, and repaints once on dismissal, at full and narrow width;
- ASCII/no-colour fallback is captured uncoloured, ASCII-only and wrapped at 40
  columns (`18`, `19`, `21`);
- narrow/idle resize is captured from `1000x620` to `620x420` with draft/caret
  preserved (`22`–`26`); those frames predate the native observation path added
  by the post-review fixes, which now reflows an idle prompt without a keystroke
  (Windows console and POSIX PTY checks) and is not re-captured as a screenshot;
- repeated prompts (`27`), a genuine required-value rejection and recovery
  (`28`, `29`), cancellation (`30`) and interruption (`31`) are captured at this
  revision, and the superseded `7676a5f` cleanups are deleted.

Verification at the accepted revision: `dart format` (152 files, 0 changed),
`dart analyze` (`No issues found!`), the doc-link check (244 links, 58 files),
the full suite (`+952`), 73 focused GUI/session/help/resize tests, the 144-test
component matrix, four local Windows console scenarios plus six local ConPTY
cases, and the fresh six-job matrix
[43741678302](https://github.com/louiss0/trelis/actions/runs/43741678302)
(success at the publishing revision, code byte-identical to the accepted one).

A post-review round then made the idle resize seam reachable and re-ran every
affected check at the new revision (154 files, 961 tests, a fresh six-job
matrix, a Windows console resize scenario and a POSIX PTY resize scenario); the
verdict, its artifact pointers and its limitations are unchanged. The
dispositions — including the two evidence corrections carried here — are in
[the post-review record](../../../../doc/evidence/trelis-backend/post-review-fixes.md).

Limitations are carried forward rather than waived: Linux/macOS evidence is
CI-only, Windows native checks inject console records or use a pseudoconsole,
the visible GUI run is one host with agent-injected synthetic input, the visible
GUI frames predate the native resize observation so live-reflow evidence is
native/CI rather than a screenshot, NVDA was absent so there is no speech or
accessibility qualification, and Unicode/cluster width policy is not a universal
terminal/font claim. Theme integration is unblocked as its own separate handoff;
this ticket does not start it and grants no release-wide accessibility claim.

The accepted verdict and artifact pointers are mirrored into the retained
compatibility gate
[`issues/16-backend-evidence-gate.md`](../../trelis-backend-implementation/issues/16-backend-evidence-gate.md),
which this branch tracks together with
[ticket 31](31-platform-ci-native-evidence.md) and the normative
[B requirements](../../trelis-backend-implementation/spec.md).