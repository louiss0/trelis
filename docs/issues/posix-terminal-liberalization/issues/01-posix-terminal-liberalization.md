# 01 POSIX terminal liberalization

Status: resolved

**Blocked by:** none

**What to build:** Replace the `Platform.isLinux || Platform.isMacOS` dispatch allowlist with `!Platform.isWindows` so any POSIX host attempts the termios transport and fails closed at the existing `stdin.hasTerminal`/`tcgetattr`/`tcsetattr` gates. Gather the five libc bindings (`tcgetattr`, `tcsetattr`, `cfmakeraw`, `poll`, `read`) into one `_PosixC` value resolved eagerly before acquisition; `tryResolve()` returns null on a missing symbol or unusable process library and `_posixTerminal` maps that to `Unavailable('Terminal capability unavailable.')`. `_posixInput` receives the resolved bindings instead of looking symbols up mid-acquisition. Guard `ProcessSignal.sigwinch.watch()` so a console that cannot notify yields the empty stream, and add an optional notification-source factory to `nativeConsoleResizeObserver` for tests. In `path_input.dart`, use the POSIX inspection branch on `!Platform.isWindows` with the thread-local errno accessor resolved through a new standalone seam `lib/src/posix_errno.dart` probing `__error`, `__errno`, `___errno`, `__errno_location` in order. See the [spec](../spec.md).

## Acceptance criteria

- [x] `_terminal` dispatches every non-Windows platform to `_posixTerminal`; the `unavailable on this platform` refusal is gone.
- [x] `_PosixC` resolves `tcgetattr`, `tcsetattr`, `cfmakeraw`, `poll`, and `read` eagerly; `tryResolve()` failure returns `Unavailable('Terminal capability unavailable.')` before acquisition. No FFI symbol lookup happens after termios raw mode is set.
- [x] `_posixInput` no longer opens `DynamicLibrary` or resolves symbols; it uses the `_PosixC` bindings.
- [x] `nativeConsoleResizeObserver` accepts an optional notification-source factory; a throwing source or a platform without `SIGWINCH` watching yields the empty stream and keeps the bounded fallback cadence.
- [x] `_pathInspectionFailure` probes `access` + errno on `!Platform.isWindows`; errno accessor resolution probes the four names in order and an unresolvable accessor returns the existing generic message.
- [x] New `lib/src/posix_errno.dart` is a standalone library absent from the public barrel, imported by `path_input.dart` and by tests directly.
- [x] Tests cover the injected-notification failure path and errno accessor resolution (non-null and correct ENOENT on POSIX, null on a library lacking the symbols).
- [x] `test/posix_terminal_pty.py` scenarios unchanged; `dart analyze` clean; full `dart test` green.

## Answer

Implemented the spec exactly as written, with three additions surfaced during review:

- **Dispatch**: `_terminal` now sends every non-Windows host to `_posixTerminal` (`lib/src/text_input.dart:4041`), replacing both the Linux/macOS allowlist and the `unavailable on this platform` refusal. The new comment records why: Dart cannot name the BSDs or Solaris, so capability probing replaces an OS allowlist, and every gate fails closed.
- **`_PosixC`** (`lib/src/text_input.dart:3801-3850`): all five libc symbols resolve eagerly at construction inside `tryResolve()` — `cfmakeraw` is a BSD/GNU extension absent from older Android bionic, so a missing symbol becomes `Unavailable('Terminal capability unavailable.')` rather than a thrown lookup. `_posixInput` takes the resolved bindings; no lookup can fire after `tcsetattr` sets raw mode.
- **Resize**: `nativeConsoleResizeObserver` gained an injectable `notificationSource` factory (`lib/src/native_resize.dart:65`); the real `_consoleResizeNotifications` and any injected source both pass through a guard that maps a thrown source to the empty stream, keeping the bounded fallback poll.
- **Path probe**: `_pathInspectionFailure` uses the POSIX branch on `!Platform.isWindows` (`lib/src/path_input.dart:438`) and resolves errno through `lib/src/posix_errno.dart`, which probes `__error`, `__errno`, `___errno`, `__errno_location` in order. The `lookup` seam is injectable so the null path and probe order are tested on every CI OS.
- **Review-driven additions**: (1) `ProcessSignal.sigint.watch()` inside `_posixInput` is now guarded — a platform that cannot watch signals still receives a typed byte 3, only an externally sent signal goes undelivered; (2) the defensive `Cannot determine whether target exists on this platform.` tail in `_pathInspectionFailure` was kept rather than deleted, because falling through would report a confirmed absence (the unsafe direction); (3) `README.md`'s stale "Interactive console input currently requires Windows" line now documents Windows/POSIX consoles and the best-effort wording the spec requires; (4) stale `text_input.dart` line references in `assets/automatic-mode-resolution.md` were refreshed.
- **Tests**: `test/posix_errno_test.dart` (3 tests: null on a symbol-less library, probe order via injected lookup, ENOENT after a failing `access` with errno read before any matcher runs); `test/native_resize_test.dart` gained the thrown-notification-source case. Full `dart test` green (5,722 tests); `dart analyze` clean; tracker and doc-link checks pass. `test/posix_terminal_pty.py` unchanged — POSIX CI still owns recorded-environment evidence.

## Comments
