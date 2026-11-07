# Terminal backend decision and patch status

## Implementation decision

The component library now deliberately uses its in-repo terminal/session backend,
with Dart FFI for native console lifecycle handling. The user explicitly chose to
keep this backend rather than migrate the component suite to Dart TUI. The ticket
01 investigation found that the inspected Dart TUI 3.0.0 implementation did not
satisfy the required alternate-stream ownership, EOF, and reliable Windows
restoration contracts without further changes. The historical Dart TUI prototype
and patch remain useful evidence, but are not the production backend.

## Outcome of prototyping

The validated direction is to build Prompty's prompts on **Dart TUI
(`dart_tui`)**, rather than continue implementing terminal interaction around
`dart_console`. Keep Prompty responsible for prompt semantics and the visual
structures in the [theme reference](../example/prototype-themes/structures.html).

**Main contains visual references and this decision only.** It adds no direct
dependencies on `dart_console`, `dart_tui`, `ffi`, or `win32`, and does not contain
the runnable terminal prototypes or the local patched dependency. Those experiments are
preserved on `prototype/cli-theme-atlas` at commit
`8483a5a343bb595fdbeb3b3b5881e5233c285e90`.

This is an implementation direction validated by prototypes, not a completed
public library API or an unqualified cross-platform compatibility guarantee.

## Relationship between dart_console and Dart TUI

They are **alternative foundations**, not two layers we need to combine.
Dart TUI 3.0.0 does not depend on `dart_console`.

| Responsibility | dart_console baseline | Dart TUI trial |
|---|---|---|
| Raw mode, key input, terminal dimensions | Low-level facilities supplied by `dart_console` | Managed by Dart TUI's `Program` and platform implementation |
| Escape-sequence decoding, paste and mouse events | Async key reader was usable, but required care and a Windows mouse-input safeguard in our demo | Typed messages and protocol parsing supplied by Dart TUI |
| Rendering, cursor placement and terminal lifecycle | Explicit repaint, flush, cursor, setup and cleanup code in our demos | `Program` and custom `View` content |
| Input editing | Implemented in our baseline demo | Built-in `TextInputModel` |
| Choice navigation and checkbox state | Implemented in our baseline demos | Built-in `SelectListModel` and `MultiSelectModel` |
| Validation, answer IDs, disabled options, letter-jump policy, retry/submission rules | Prompty/demo responsibility | Still Prompty/demo responsibility |
| Theme colors and prompt structures | Prompty/demo responsibility | Still Prompty/demo responsibility |

The trial's disabled-option policy passes only enabled choices into Dart TUI's
selection models, then maps their cursors back to the complete displayed list.
This keeps disabled options visible but not focusable/selectable. Custom views
preserve the rail, rounded and inline layouts without using stock form layouts.

Do not run both libraries' terminal sessions or stdin readers concurrently.
Switching backend does not require retaining `dart_console` as a runtime layer.
The old examples exist as comparison evidence, not as a dependency of the newer
examples. Also distinguish **TUI**, the generic term “terminal user interface,”
from **Dart TUI**, the specific `dart_tui` package evaluated here.

## Important: the successful trial used a local patch

**The evaluated dependency is locally patched Dart TUI 3.0.0, not the unmodified
pub.dev release. The patch is to Dart TUI, not to dart_console or Prompty.**

Unpatched 3.0.0 passed the tested prompt interactions but failed exact Windows
terminal-mode restoration after both Escape and Ctrl+C:

```text
Console mode/cursor changed: before=503:1 after=497:1
```

The missing bits are `0x0006`: `ENABLE_LINE_INPUT` and `ENABLE_ECHO_INPUT`.
The cursor visibility (`:1`) was restored; echo and line input were not.

### Cause and minimal fix

In `Program._setRawMode(true)`, upstream 3.0.0 changed Dart's `stdin.echoMode`
and `stdin.lineMode` before `enableWindowsVtInput()` saved the original Windows
console flags. The saved snapshot therefore already had echo and line input
disabled, and cleanup restored that partially modified snapshot.

The patch moves the existing call to `enableWindowsVtInput()` **before** Dart's
echo/line setters and removes the later duplicate call. It reuses the existing
native save/restore implementation; it does not add Windows cleanup code to
Prompty's prompts. The Windows helper is a no-op on other platforms, but that
is not a substitute for cross-platform testing.

### Provenance and where the patch lives

- Upstream: <https://github.com/codenameakshay/dart_tui>
- Evaluated version: [3.0.0](https://pub.dev/packages/dart_tui/versions/3.0.0).
- Source archive: <https://pub.dev/api/archives/dart_tui-3.0.0.tar.gz>.
- Archive SHA-256: `3612ecfdb0bd6fe1f653a8268585943c9daf366698d1d1b6e889ba9b47b59fcb`.
- Archive branch: `prototype/cli-theme-atlas`.
- Fixed archive commit: `8483a5a343bb595fdbeb3b3b5881e5233c285e90`.
- Path on that commit: `third_party/dart_tui/lib/src/program.dart`.
- Patch notes on that commit: `third_party/dart_tui/PROMPTY_PATCH.md`.
- The prototype uses a **local path dev dependency**, not a modified global
  package cache. Upstream LICENSE and selected upstream tests were retained.
- No upstream issue or PR was filed by this work. Do not assume the fix has
  shipped upstream.

Inspect the archived notes without changing branches:

```powershell
git show 8483a5a:third_party/dart_tui/PROMPTY_PATCH.md
git show 8483a5a:pubspec.yaml
```

When implementation begins, either deliberately adopt the documented local
patch or verify an upstream release containing an equivalent fix. Do not add
unpatched `dart_tui: 3.0.0` and assume it has the behavior demonstrated here.
Retain the exact Windows restoration regression test, and remove a local patch
only after the replacement dependency passes it.

## Evidence preserved with the experiments

Input, Select and MultiSelect were tested through real Windows-console key
events. All six Dart TUI scenarios passed: three prompt kinds, each with Escape
and Ctrl+C. Each scenario ran two separate `Program` sessions in the same
process and compared original/final native input flags and cursor visibility.

The checks covered editing/limits/validation, choice wrapping, disabled-option
skipping, Home/End, letter jump, multiselect toggles, stable result ordering,
structure switching, submission freezing, retry and cancellation. Tests inspect
the latest rendered state rather than accepting an older matching frame from
inline scrollback. Native mouse-event injection was also exercised.

Bracketed-paste **protocol injection** verified Input normalization/control
handling/limits and that choice prompts ignore pasted control keys. This did
not test the OS clipboard or every terminal emulator's mouse protocol.
Selected upstream editor, decoder, Program and selection-model tests also passed.

The archived suite entry point is:

```powershell
# Run on the archived prototype branch, not on main:
powershell -NoProfile -ExecutionPolicy Bypass -File test/prototype_dart_tui_interactions_windows.ps1
```

Remaining production evaluation includes macOS/Linux, application-level Unicode
and display-width behavior, actual clipboard paste, resize/narrow layouts,
long scrolling lists, accessibility and error-path behavior. The 40 atlas
components are visual reference specimens, not 40 implemented prompts; see
[the exact component inventory](theme-components.md).
