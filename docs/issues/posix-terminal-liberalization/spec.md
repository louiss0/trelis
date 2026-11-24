# POSIX terminal liberalization

Status: ready-for-agent
Labels: ready-for-agent

## Problem Statement

The native interactive transport is gated by an operating-system allowlist: only `Platform.isLinux` and `Platform.isMacOS` reach `_posixTerminal`; every other platform that is not Windows receives `Unavailable('Interactive console input is unavailable on this platform.')`. Dart's `Platform` API can name only six operating systems, so the systems it cannot name — the BSDs, Solaris/illumos, and any other POSIX host — can never be added to an allowlist, and Android/Termux is named but excluded despite having termios, `poll`, and `SIGWINCH`.

The allowlist's edges are also unsound where the POSIX path does run:

- FFI symbol lookups for `tcgetattr`, `tcsetattr`, `cfmakeraw`, `poll`, and `read` are unguarded. A POSIX platform missing a symbol — older Android bionic lacks `cfmakeraw`, a BSD/GNU extension rather than standard POSIX — throws out of the acquisition path instead of returning `Unavailable`.
- `poll` and `read` are resolved inside `_posixInput` at stream creation, after termios raw mode has already been acquired, so a missing symbol fails the prompt mid-acquisition rather than before it.
- `ProcessSignal.sigwinch.watch()` is documented for Linux and macOS; on another POSIX platform it can throw `UnsupportedError`, and it is called eagerly while building the resize observer.
- `PathInput`'s native nonexistence probe selects its POSIX branch on the same four-platform allowlist. On any other POSIX system it reports `Cannot determine whether target exists on this platform.` as a validation failure, so a genuinely absent path that `allowNonexistent` should accept is rejected.

## Solution

Probe capability instead of allowlisting operating systems, keeping every failure closed:

- **Dispatch**: in `_terminal`, replace `Platform.isLinux || Platform.isMacOS` with `!Platform.isWindows`. Every failure point on the POSIX path already fails closed: `stdin.hasTerminal` gates entry, `tcgetattr` failure returns `Unavailable`, and `tcsetattr` failure returns `Cannot acquire terminal input.`. Platforms that genuinely cannot participate (iOS, Fuchsia, terminals without a controlling tty) still return `Unavailable` at those gates.
- **Eager binding resolution**: gather all five libc bindings into one `_PosixC` value (mirroring the Windows `_Console` shape) resolved once per invocation before any acquisition. `tryResolve()` catches a missing symbol or an unusable process library and returns null, which `_posixTerminal` maps to `Unavailable('Terminal capability unavailable.')`. `poll`/`read` move out of `_posixInput` into `_PosixC` so no symbol is resolved after raw mode is acquired.
- **Resize notifications**: `nativeConsoleResizeObserver` accepts an optional notification-source factory for tests; resolution failures — a platform that cannot watch `SIGWINCH`, or an injected source that throws — produce the empty stream, leaving the bounded fallback poll as the sole wake-up.
- **Path nonexistence probe**: `_pathInspectionFailure` uses its POSIX branch on `!Platform.isWindows`. The thread-local errno accessor is probed by name (`__error`, `__errno`, `___errno`, `__errno_location`) through a new standalone seam `lib/src/posix_errno.dart`, imported by `path_input.dart` (a `part` of `text_input.dart`) and by tests directly, matching the repo's src-seam convention. An unresolvable accessor keeps the existing generic failure message.

## Out of scope

- **mintty/Git Bash on Windows**: stdin is a pipe with no console mode and no termios equivalent; a third transport is a separate design.
- **Manual termios flag editing** as a `cfmakeraw` fallback: `struct termios` layouts diverge per platform; only worth it for a named target.
- **Locale conventions**: `_linuxDateProfile` (`libc.so.6`, glibc-specific) and `_linuxNumericConvention` remain Linux-gated; other POSIX systems keep the existing null-convention default. Broadening convention detection is a separate question.
- **Screen-reader hints**: `WindowsReaderProbe` and the macOS VoiceOver bridge stay gated to their platforms; unknown platforms already classify as `HintPlatform.unsupported`.

## Evidence and claim wording

The `test/posix_terminal_pty.py` recorded-environment harness exercises the POSIX path on ubuntu-latest and macos-latest in CI and must stay green unchanged. Unit tests cover the injected-notification failure and the errno accessor probe on every CI OS. Until a real BSD (or comparable) run is recorded, documentation and release notes say *best-effort POSIX support*, consistent with the accessibility-baseline requirement for recorded environments.
