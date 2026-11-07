# Trelis terminal backend decision

## Current production decision

Trelis deliberately uses its in-repository terminal/session backend, implemented
primarily in `lib/src/text_input.dart`, with Dart FFI for native console
lifecycle handling. Dart TUI and the older `dart_console` prototype are not
production dependencies and are not layered underneath this backend.

This is a **requirements-specific choice**, not a claim that a custom backend is
universally better than Dart TUI. The comparison below concerns the inspected
Dart TUI 3.0.0 archive and its archived local patch at `8483a5a`, not every
past or future Dart TUI release.

## Why this backend fits Trelis better

| Trelis requirement | Inspected Dart TUI 3.0.0 adapter | Current Trelis backend |
| --- | --- | --- |
| Exact native state restoration | Unpatched 3.0.0 saved the Windows mode after Dart changed echo/line input, so cleanup restored an already-modified snapshot. The local patch fixed that ordering and passed the archived scenarios, but the Windows helper still ignored `GetConsoleMode` failure in setup and did not check `SetConsoleMode` results. | Snapshots the selected Windows input and output modes before mutation, checks native get/set calls, and restores the exact snapshots in `finally`. The same restoration hook runs before input cleanup. Native harnesses compare before/during/after input mode, output mode and cursor state. |
| Independent input/output ownership | `withInput` and `withOutput` select streams, but raw-mode setters still target process `stdin`; dimensions also default from `stdout` rather than the selected output. | Checks `stdin` and the selected `stdout`/`stderr` independently. Prompts default to stderr, may explicitly select stdout, reject explicitly requested rich output before setup when that output is redirected, and never implicitly consume redirected stdin. |
| Explicit EOF and exit outcomes | The inspected `Program` input subscription mapped input errors to interruption but had no `onDone` path that produced Trelis's required input-ended outcome. Adapters would still need to define accepted, cancelled, interrupted, EOF and unavailable semantics. | `_Keys` propagates stream completion, and components return the sealed `Accepted`, `Cancelled`, `Interrupted`, `InputEnded` or `Unavailable` outcomes. EOF never becomes acceptance. The evidence records distinguish injected console EOF gestures, real closed streams, and unexecuted POSIX checks rather than treating them as equivalent. |
| Repeatable sessions without competing readers | The archived runtime used shared/default stdin coordination and a helper isolate. The patched prototype passed its repeated Windows scenarios, but adopting it meant retaining that runtime and its lifecycle patch. | Owns one authorized console handle/descriptor per session, rejects overlapping terminal sessions, and closes per-session decoders/subscriptions in `finally`. Windows reads `ReadConsoleInputW` directly rather than cancelling Dart's process-wide stdin subscription; POSIX reads the authorized descriptor directly. |
| Equivalent rich and linear prompt tasks | Dart TUI supplies a general program loop, renderer and stock models. Trelis would still need a separate sequential interaction, shared command grammar, validation recovery and explicit component outcomes. | The same public components drive rich in-place and sequential linear interactions, including editable defaults, persistent validation guidance, exact linear commands, literal paste handling and reviewable final state. Ticket 31's public matrix exercises all 38 components at this seam. |
| Bounded, source-inspected responsibility | A general TUI runtime includes alternate-screen/cell rendering, animation ticks, mouse and other behavior outside Trelis's prompt-session seam. The evaluated Windows trial additionally required a local patch. | The terminal adapter owns only capability negotiation, native state, input decoding and session cleanup. Prompt semantics remain in Trelis. The terminal layer has no `dart_tui`, `dart_console` or `win32` dependency and uses the pinned `ffi` package directly. |

The strongest justification is therefore **contract locality**: the behavior that
caused the Dart TUI prototype to need investigation and a patch is implemented,
checked and regression-tested at Trelis's own session seam. A failure in stream
ownership, EOF, restoration or linear fallback can be fixed and verified without
modifying a third-party renderer. That is leverage for this library, not proof
that custom terminal code is always the better engineering choice.

## What Dart TUI still offers

Dart TUI was the stronger general-purpose TUI prototype. It supplied a typed
message/decoder model, alternate-screen and cell rendering, cursor management,
mouse events, animation ticks, and stock text/selection models. Those features
can reduce the cost of building a full-screen application. Trelis does not claim
feature parity with that runtime: its current backend is deliberately narrower,
uses polling for native input, and implements the prompt structures it needs
rather than a general TUI toolkit.

A future Dart TUI release could also change the findings above. Reconsider it
only by pinning and inspecting that exact release and passing Trelis's current
public and native lifecycle suites. Do not infer correctness from a changelog or
from the archived local patch.

## Current evidence and limitations

- [Ticket 31 regression evidence](ticket-31-regression-evidence.md) records the
  76-case public rich/linear acceptance matrix and the executed Windows native
  checks. Console input injection is not the same as real keyboard, clipboard,
  IME, rendering or NVDA evidence.
- [The original lifecycle probe](terminal-probe.md) records exact repeated
  submit, Escape, Ctrl+C, injected EOF and recoverable-error restoration checks.
  It also distinguishes a real closed input stream from an injected console EOF
  gesture.
- POSIX terminal support is implemented and PTY/CI checks exist, but the local
  evidence file explicitly records Linux/macOS execution as unverified. Do not
  turn implementation or workflow configuration into a platform pass.
- A declared `TERM=dumb` is never treated as rich-capable, even when the stream
  reports a terminal: explicit rich mode returns an unavailable outcome instead
  of writing escape sequences, and automatic mode stays linear. The POSIX reader
  additionally watches for a delivered `SIGINT` so Ctrl+C produces the interrupt
  outcome through the signal path as well as the input byte. The Windows harness
  records `dumb-auto` and `dumb-rich`; the new PTY `signal`, `dumb-auto` and
  `dumb-rich` cases are configured but unexecuted here.
- No whole-library accessibility qualification exists. The Windows Terminal +
  NVDA baseline for all 38 components remains unperformed, and this backend
  receives no universal accessibility claim from the component or native tests.
- Forced process termination, every terminal emulator, every keyboard layout,
  and every transport are not claimed as qualified or restored configurations.

## Historical Dart TUI prototype and patch

The original prototyping direction was Dart TUI rather than extending the
`dart_console` demonstration. That was a valid prototype decision, superseded by
the current production decision after the ticket 01 source investigation. The
two libraries were always alternative terminal foundations, not layers that
needed to run together.

The successful Windows Dart TUI trial used **locally patched Dart TUI 3.0.0**.
Unpatched 3.0.0 failed exact echo/line-input restoration after Escape and
Ctrl+C:

```text
Console mode/cursor changed: before=503:1 after=497:1
```

The missing bits were `0x0006`: `ENABLE_LINE_INPUT` and `ENABLE_ECHO_INPUT`.
The patch moved `enableWindowsVtInput()` before Dart's echo/line setters in
`Program._setRawMode(true)`, so the saved snapshot preceded those mutations.
The archived trial then passed its tested Input, Select and MultiSelect Escape,
Ctrl+C and repeated-session scenarios. Those results belong to that archived
prototype, not to the current backend or an unpatched release.

Preserved provenance:

- Upstream: <https://github.com/codenameakshay/dart_tui>
- Evaluated version: 3.0.0; source archive
  <https://pub.dev/api/archives/dart_tui-3.0.0.tar.gz>.
- Archive SHA-256: `3612ecfdb0bd6fe1f653a8268585943c9daf366698d1d1b6e889ba9b47b59fcb`.
- Archive branch/commit: `prototype/cli-theme-atlas`, `8483a5a343bb595fdbeb3b3b5881e5233c285e90`.
- Patched source: `third_party/dart_tui/lib/src/program.dart` on that commit.
- Patch notes: `third_party/dart_tui/PROMPTY_PATCH.md` on that commit.
- No upstream issue or PR was filed by this work; do not assume the fix shipped.

Inspect the archive without changing branches:

```powershell
git show 8483a5a:third_party/dart_tui/PROMPTY_PATCH.md
git show 8483a5a:third_party/dart_tui/lib/src/windows_terminal.dart
git show 8483a5a:pubspec.yaml
```

See [the ticket 01 source investigation](terminal-backend-ticket-01-investigation.md)
for the specific stream, EOF and native-error findings that reopened the
prototype decision. The retained theme atlas is a visual reference, not a
backend or an accessibility qualification.
