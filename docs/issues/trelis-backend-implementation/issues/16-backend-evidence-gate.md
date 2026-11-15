# Accept the backend evidence gate
Status: resolved
Resolved: accepted verdict mirrored from [33: Accept or block the backend evidence gate](../../trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md) on 2026-11-15
Blocked by: [Execute the cross-platform automated and native matrix](../../trelis-backend-tracer-bullets/issues/31-platform-ci-native-evidence.md), [Exercise the backend through agent-operated Windows computer use](../../trelis-backend-tracer-bullets/issues/32-agent-windows-gui-evidence.md)
Execution: retained compatibility gate, not an independent implementation task
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Independently audit the completed backend and its evidence before unblocking named-theme integration.

## Acceptance

- [B-GATE](../spec.md#b-gate)

- [ ] Confirm every implementation task is resolved and every B requirement has current pass evidence or an explicitly justified non-applicable subcase; required platform/GUI checks cannot be waived by wording.
- [ ] Verify all-platform CI/native results and Windows agent GUI observations refer to the accepted revision; rerun affected evidence after fixes.
- [ ] Check no partial/old/configured-only result is represented as a pass, no human checkpoint is hidden in the plan and no accessibility claim is inferred from automation.
- [ ] Publish doc/evidence/trelis-backend/backend-acceptance.md with requirement-to-artifact links, migration notes, limitations and an explicit accepted/blocked verdict.
- [ ] Only an accepted verdict/resolved gate task unblocks the separate theme handoff; do not start theme implementation as part of this audit.

## Evidence required

An explicit audited backend-acceptance report. Until accepted, the theme integration handoff remains blocked.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

The user approved a finer, end-to-end [33-ticket backend plan](../../trelis-backend-tracer-bullets/dependencies.md) in place of the unstarted layered decomposition. This file remains the unresolved acceptance reference used by unchanged parent specifications. No backend acceptance is claimed. The replacement [Accept or block the backend evidence gate](../../trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md) audits the active backlog and mirrors only an actually accepted verdict and evidence here before resolving. The platform/GUI prerequisites above refer to the replacement plan; no superseded task is treated as implemented.

## Mirrored accepted verdict

- **Verdict: accepted** at source revision
  `81738e8a9e7278f872ab4b6c7c404c111607a4e2`, published by
  [33: Accept or block the backend evidence gate](../../trelis-backend-tracer-bullets/issues/33-backend-evidence-gate.md).
  That revision's code is byte-identical to `b94efda3…`, where every Windows GUI
  capture was made (`git diff --stat b94efda 81738e8` lists only `doc/` and
  `docs/issues/` paths).
- **Audit report:** `doc/evidence/trelis-backend/backend-acceptance.md`
  (requirement-to-artifact matrix for B-BASE…B-GATE, ticket audit, limitations,
  and the explicit accepted verdict).
- **Platform/native evidence:** fresh six-job matrix
  [run 43740821935](https://github.com/louiss0/trelis/actions/runs/43740821935)
  (`success`): three Dart jobs at `+952` tests, two POSIX PTY jobs with ten
  scenarios each, one Windows native job with 17 console scenarios and six
  pseudoconsole cases.
- **Windows agent GUI evidence:**
  `doc/evidence/trelis-backend/32-agent-windows-gui.md` with
  `doc/evidence/trelis-backend/gui/11…31` — concurrent editing and caret
  (`11`–`13`), modal help and dismissal (`14`, `15`, `25`, `26`), private entry
  (`16`, `17`), ASCII/no-colour (`18`, `19`, `21`), narrow/idle resize
  (`22`–`24`), repeated prompts (`27`), required-value rejection and recovery
  (`28`, `29`), cancellation and interruption (`30`, `31`).
- **Limitations carried forward, not waived:** Linux/macOS evidence is CI-only;
  Windows native checks inject console records or use a pseudoconsole; the
  visible GUI run is one host with agent-injected synthetic input; the visible
  GUI frames were captured before the native resize observation existed, so the
  live idle-reflow claim rests on the Windows console and POSIX PTY checks
  recorded in [the post-review record](../../../../doc/evidence/trelis-backend/post-review-fixes.md)
  rather than on those stills; NVDA was absent, so there is no speech or
  accessibility qualification; Unicode cluster/width policy is not a universal
  terminal/font claim; forcible process termination is outside the restoration
  contract.

### Disposition of this file's acceptance bullets

- *Every implementation task resolved and every B requirement with current pass
  evidence:* satisfied for the replacement 33-ticket plan (tickets 01–32
  resolved, B-BASE…B-GATE each mapped to executed evidence). The layered tasks
  written in this directory were superseded before execution and are **not**
  claimed as implemented.
- *Platform/GUI evidence refer to the accepted revision, affected evidence
  re-run:* satisfied as recorded above.
- *No partial/old/configured-only result passed off as a pass, no hidden human
  checkpoint, no accessibility claim from automation:* satisfied — the audit
  records the two earlier blocked verdicts, excludes superseded captures, and
  claims no accessibility qualification.
- *Publish the acceptance report:* satisfied by
  `doc/evidence/trelis-backend/backend-acceptance.md`.
- *Only an accepted verdict unblocks the separate theme handoff:* the handoff is
  now unblocked, and no theme implementation was started here.

This status line resolves the acceptance gate only. The planning header of
[the specification](../spec.md) (`Status: planned`, `Acceptance: not verified`)
still describes the unexecuted layered decomposition and is intentionally left
as it stands rather than rewritten into an implementation claim.
