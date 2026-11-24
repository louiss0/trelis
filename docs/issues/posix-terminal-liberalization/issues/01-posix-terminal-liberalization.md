# 01 POSIX terminal liberalization

Status: claimed

**Blocked by:** none

**What to build:** Replace the `Platform.isLinux || Platform.isMacOS` dispatch allowlist with `!Platform.isWindows` so any POSIX host attempts the termios transport and fails closed at the existing `stdin.hasTerminal`/`tcgetattr`/`tcsetattr` gates. Gather the five libc bindings (`tcgetattr`, `tcsetattr`, `cfmakeraw`, `poll`, `read`) into one `_PosixC` value resolved eagerly before acquisition; `tryResolve()` returns null on a missing symbol or unusable process library and `_posixTerminal` maps that to `Unavailable('Terminal capability unavailable.')`. `_posixInput` receives the resolved bindings instead of looking symbols up mid-acquisition. Guard `ProcessSignal.sigwinch.watch()` so a console that cannot notify yields the empty stream, and add an optional notification-source factory to `nativeConsoleResizeObserver` for tests. In `path_input.dart`, use the POSIX inspection branch on `!Platform.isWindows` with the thread-local errno accessor resolved through a new standalone seam `lib/src/posix_errno.dart` probing `__error`, `__errno`, `___errno`, `__errno_location` in order. See the [spec](../spec.md).

## Acceptance criteria

- [ ] `_terminal` dispatches every non-Windows platform to `_posixTerminal`; the `unavailable on this platform` refusal is gone.
- [ ] `_PosixC` resolves `tcgetattr`, `tcsetattr`, `cfmakeraw`, `poll`, and `read` eagerly; `tryResolve()` failure returns `Unavailable('Terminal capability unavailable.')` before acquisition. No FFI symbol lookup happens after termios raw mode is set.
- [ ] `_posixInput` no longer opens `DynamicLibrary` or resolves symbols; it uses the `_PosixC` bindings.
- [ ] `nativeConsoleResizeObserver` accepts an optional notification-source factory; a throwing source or a platform without `SIGWINCH` watching yields the empty stream and keeps the bounded fallback cadence.
- [ ] `_pathInspectionFailure` probes `access` + errno on `!Platform.isWindows`; errno accessor resolution probes the four names in order and an unresolvable accessor returns the existing generic message.
- [ ] New `lib/src/posix_errno.dart` is a standalone library absent from the public barrel, imported by `path_input.dart` and by tests directly.
- [ ] Tests cover the injected-notification failure path and errno accessor resolution (non-null and correct ENOENT on POSIX, null on a library lacking the symbols).
- [ ] `test/posix_terminal_pty.py` scenarios unchanged; `dart analyze` clean; full `dart test` green.

## Comments
