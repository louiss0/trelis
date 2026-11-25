# 04 Public theme-instance native fixture routes and behavior matrix

Status: ready-for-agent

**Blocked by:** none

**What to build:** Implement the specialized native fixture behavior through exported theme instances over TerminalEnvironment.nativeThemeDefault before any scenario is called public coverage. Cover correct rich/linear interaction selection, initial drafts for cursor and long-line editing, resize draft behavior, repeat/reacquisition, validation recovery, redirected or dumb-output behavior, password help, cancellation/interruption/EOF outcomes, and session retirement with writer failure. The session-retirement fixture must use theme-owned feedback coexisting with a prompt across the shared session and prove writer failure retires the parked prompt while native console state is restored. Add compact Dart lifecycle-matrix coverage only where it exercises behavior through the public seam. See the [spec](../spec.md), especially “Public native lifecycle coverage and CI”.

## Acceptance criteria

- [ ] Native fixtures counted as public coverage construct reusable exported theme instances and invoke parameterless prompt/feedback methods; direct constructors and the internal compatibility barrel are not used.
- [ ] Required specialized fixture behaviors exist rather than merely being relabeled: rich/linear selection, initial drafts, resize behavior, repeat/reacquisition, validation recovery, output refusal/redirection, password help, cancellation/interruption/EOF, and writer-failure retirement.
- [ ] The session-retirement fixture proves feedback/prompt coexistence, parked-prompt retirement on writer failure, and console restoration.
- [ ] Compact public lifecycle Dart tests cover reusable prompts, rich/linear outcomes, EOF, cleanup/reacquisition, feedback coexistence, and failure recovery through the public seam.
- [ ] Focused fixture, lifecycle, analyzer, and test commands pass.

## Comments
