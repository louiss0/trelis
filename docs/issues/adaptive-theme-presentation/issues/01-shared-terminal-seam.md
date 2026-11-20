# 01 Preserve the shared terminal seam

Status: resolved

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
- [x] Existing prompt and feedback behavior works through the seam, including native stdin handling, reader ownership and restoration; add focused regression tests.
- [x] Multiple internal participants share the existing reader rather than creating competing stdin subscriptions; cover no-active-work and sequential use.
- [x] Inject acquisition, writer and restoration failures; assert resources are restored where acquired and failures remain observable, including simultaneous primary and restoration failures.
- [x] Run relevant terminal session and I/O tests and record commands and results; record native behavior not verified rather than claiming native evidence.

## Comments

Added `lib/src/shared_terminal.dart` as an internal, non-exported seam with
`SharedTerminalLease`, `SharedTerminalReader`/`SharedReaderCoordinator` and
`SharedOutputCoordinator`. Public prompt, session and feedback calls are
unchanged; native transports keep their one-prompt restore callback and a
per-invocation lease. The shared reader is keyed by the selected input stream,
so participants do not open competing subscriptions and sequential prompts keep
buffered input and editor parsing. Acquisition happens before an operation
starts; restoration runs once; a primary failure and a restoration failure are
both retained without stringifying application text. A failed writer records
the original error, replays it on later writes and retires its reader and live
regions.

Validation performed after the implementation slices:

- `dart pub get` — succeeded (54 dependencies changed).
- `dart test test/terminal_io_test.dart test/terminal_session_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_session_feedback_test.dart test/terminal_session_modal_help_test.dart test/terminal_session_short_screen_test.dart test/feedback_test.dart test/shared_terminal_lease_test.dart test/shared_terminal_reader_test.dart test/shared_terminal_writer_test.dart` — all 75 relevant tests passed.
- `dart test` — all 4822 tests passed.
- `dart format --output=none --set-exit-if-changed .` — 0 files changed, exit 0.
- `dart analyze` — no issues found.

Honest gaps: no native Windows console, screen-reader, real-terminal or human
evidence was gathered here; native stdin and restoration were preserved in the
code path but not exercised on a real console. Terminal ownership identity and
theme-owned active periods remain outside this ticket.
