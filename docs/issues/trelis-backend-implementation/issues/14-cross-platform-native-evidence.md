# Run Windows, Linux and macOS backend regression and native evidence
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 13
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Extend and execute the platform matrix for the new backend and archive current-revision native/PTY evidence.

## Acceptance

- [B-PLATFORM](../spec.md#b-platform)
- [B-CAP](../spec.md#b-cap)
- [B-RESIZE](../spec.md#b-resize)
- [B-FAIL](../spec.md#b-fail)

- [ ] Run format/analyze/doc links/full Dart/public matrices on Windows, Ubuntu and macOS CI.
- [ ] Execute actual POSIX PTY scenarios inside Linux/macOS CI, adding new profile/compositor/resize/failure cases instead of claiming syntax checks as runtime evidence.
- [ ] Execute Windows native/ConPTY scenarios and extend selected-stream, dumb/redirected, modal/resize/repeated-session/restoration coverage.
- [ ] Record CI URLs/artifacts and SDK/runner/environment/revision; investigate unexplained new failures rather than passing repeated reruns by assumption.
- [ ] No physical Linux/macOS access or human confirmation is required; unavailable CI evidence keeps this task pending.

## Evidence required

Fresh CI/native report and artifacts for all three platforms, with failures/pending evidence explicit.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
