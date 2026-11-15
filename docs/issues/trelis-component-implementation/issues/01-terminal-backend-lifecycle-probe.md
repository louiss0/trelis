# 01: Prove the terminal backend and restoration lifecycle

Parent: [Accessible terminal prompt component specification](../../trelis-accessible-prompts/spec.md)

**What to build:** Deliver a minimal working terminal probe using a deliberately selected, source-inspected backend. A caller can run repeated real Windows console sessions, provide input, and leave through submission, Escape, Ctrl+C, EOF and recoverable errors without inherited terminal state being damaged. The probe demonstrates actual stream ownership and identifies unsupported arrangements instead of silently changing them.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Pin and inspect the exact backend revision and raw-mode/save-restore implementation before relying on it.
- [x] Real Windows integration checks compare original/final console flags and cursor state across all supported exits and repeated sessions.
- [x] The probe separates input and output stream ownership and avoids competing readers.
- [x] Explicit rich capability failure occurs before partial setup; no silent downgrade or controlling-terminal takeover occurs.
- [x] Historical prototype results are not reused as evidence of a current backend pass; record actual source identity and observed results.
