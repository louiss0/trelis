# 03 Native F1 help and harmless unassigned function keys

Status: ready-for-agent

**Blocked by:** [02](02-conpty-staging-and-diagnostics.md)

**What to build:** Reconnect every native help fixture to F1 and prove modal help behavior through real terminal harnesses. Split the existing ConPTY function-key coverage into an F1 contract (open help, do not nest, input remains modal, Escape restores prior screen/caret, ordinary input can still complete) and an unassigned-function-key control (no edit, corruption, or blockage). Windows TextInput scenarios cover normal and secret help, hidden-entry protection, repeated F1, Escape restoration, and final outcomes. VT-oriented scenarios use recognized SS3 or CSI F1 encodings; no release fixture may use Ctrl+T as help. See the [spec](../spec.md).

## Acceptance criteria

- [ ] Windows console probes send actual F1 console key events and VT scenarios send recognized F1 encodings; no fixture uses Ctrl+T for help.
- [ ] F1 opens component help, repeated F1 does not nest, typed input while help is open is not answer data, and Escape restores prior screen and caret state.
- [ ] Secret entry is never disclosed through help; normal final outcomes still complete after dismissal.
- [ ] An unassigned function key neither edits nor blocks the answer.
- [ ] Corrected Windows native scenarios pass with staged waits and structured diagnostics.

## Comments
