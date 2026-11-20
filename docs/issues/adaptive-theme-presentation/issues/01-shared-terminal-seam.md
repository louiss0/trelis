# 01 Preserve the shared terminal seam

Status: claimed

**Blocked by:** None

**What to build:** Extract or adapt the existing shared reader, terminal leases and feedback coordination into an internal seam usable by a future theme owner. Preserve Windows native stdin, per-invocation leases and existing editor safety; this is not a standalone editor audit. Keep current public calls buildable until the coordinated cutover. See the [spec](../spec.md) and [plan](../../../adaptive-theme-implementation-plan.md).

Illustrative Dart — **PROPOSED, NOT IMPLEMENTED**:
```dart
final lease = await sharedTerminal.acquire();
try {
  await runComponent(lease.reader, lease.writer);
} finally {
  await lease.release();
}
```

## Acceptance criteria
- [ ] Existing prompt and feedback behavior works through the seam, including native stdin handling, reader ownership and restoration; add focused regression tests.
- [ ] Multiple internal participants share the existing reader rather than creating competing stdin subscriptions; cover no-active-work and sequential use.
- [ ] Inject acquisition, writer and restoration failures; assert resources are restored where acquired and failures remain observable, including simultaneous primary and restoration failures.
- [ ] Run relevant terminal session and I/O tests and record commands and results; record native behavior not verified rather than claiming native evidence.
