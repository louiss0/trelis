# Verify the backend through agent-operated Windows computer use
Status: wontfix
Labels: wontfix
Resolution: superseded, not implemented
Superseded by: [Approved backend tracer-bullet execution order](../../trelis-backend-tracer-bullets/dependencies.md)
Blocked by: 13
Parent: [Trelis backend-first implementation specification](../spec.md)

## What to build

Use an agent and the installed computer-use skill to exercise the implemented backend in a visible Windows terminal, replacing the proposed human checkpoint.

## Acceptance

- [B-GUI](../spec.md#b-gui)
- [B-SECRET](../spec.md#b-secret)
- [B-MODAL](../spec.md#b-modal)
- [B-RESIZE](../spec.md#b-resize)

- [ ] Read the computer-use skill and version-matched CLI guide before controlling a dedicated visible test terminal; use programmatic setup where possible.
- [ ] Exercise editable defaults/caret, shared feedback/Text updates, modal help/dismissal, idle/narrow resize, ASCII/no-colour fallback and repeated/error/cancel/interruption cleanup.
- [ ] Use synthetic secret canaries and observe hidden/masked behavior without real credentials; distinguish generated GUI input from physical keyboard use.
- [ ] Capture screenshots and checkpoint expected/observed notes; inspect NVDA speech where available and record version/config/source or its explicit absence.
- [ ] Do not claim human usability, physical Linux/macOS verification or accessibility qualification. Missing GUI tooling/window is blocked, not an automatic pass or a human fallback requirement.

## Evidence required

Agent computer-use report with current revision, tool/terminal/input method, screenshots, observed behavior and limitations.

Not executed. Record actual revision, commands/scenarios, environment, results and artifact pointers before resolving. Apply the specification's evidence schema; never substitute this plan for a pass.

## Comments

Superseded with the user's approval by the finer [backend tracer-bullet plan](../../trelis-backend-tracer-bullets/dependencies.md). This former layered ticket was not implemented and its unchecked criteria are not acceptance evidence. Do not execute it as a competing backlog; work the replacement plan's unblocked frontier. The retained backend gate remains unresolved until genuine implementation and verification pass.
