# 10: Emit meaningful linear TextInput history

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Read a sequential prompt transcript that preserves real actions without treating repaint activity as new conversation.

**Blocked by:**
- [05: Render TextInput from safe typed presentation content](05-safe-typed-text-input.md)

**Status:** resolved

**Acceptance reference:** [B-EVENT](../../trelis-backend-implementation/spec.md#b-event), [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity).

- [x] Separate current views from ordered, identified presentation events at the public prompt boundary.
- [x] Keep new identical-text help/validation occurrences while preventing duplicates from no-op keys, repaint and resize.
- [x] Preserve meaningful caret-only changes and literal-command/paste behavior.
- [x] Do not infer acceptance or task outcomes from snapshot differences or treat onChanged callbacks as reliable change events.
- [x] Verify clean real-redirected output and deterministic ordering with public transcripts.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Answer

Implemented on `ticket/backend-10-linear-events` in commit `ff73f96`. The public `ScriptedInput(transcript: TextInputTranscript())` seam now separates current editable views from ordered identified presentation events, preserves genuine repeated help and validation occurrences plus caret/paste/literal provenance, and does not infer events from snapshots or `onChanged`. Redirected native output and deterministic ordering are verified. Evidence is recorded in `assets/evidence/trelis-backend/ticket-10-linear-events.md` and `ticket-10-redirected.txt`.
