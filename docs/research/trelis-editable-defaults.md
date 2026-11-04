# Editable initial defaults in Trelis terminal prompts

Research date: **2026-11-03**, host local offset **UTC−05:00**.  
Scope: documentation and primary-source research; **no implementation, platform tests or assistive-technology tests were performed**.

## Conclusion

Actual editable initial values are technically plausible, but **not established as universally available or accessible in either interaction mode**.

- **Dart `stdin.readLineSync()` alone is insufficient:** it has no initial-buffer argument or editor-state API. Printing a default before reading does not put it into the editable input buffer.
- **POSIX cooked input is not a portable prefilled line editor.** Its standardized line discipline provides buffering and erase/kill processing, not an API for installing arbitrary editable initial text.
- **Windows has a native candidate:** `ReadConsoleW` with `CONSOLE_READCONSOLE_CONTROL.nInitialChars`. Microsoft documents preservation of initial buffer characters, but the exact display, cursor/editing, output-handle and terminal-host behavior required by Trelis needs a prototype.
- **Application-managed editors can hold initial text:** GNU Readline provides explicit buffer-editing hooks; Dart TUI packages document editable text models. Those mechanisms are not automatically equivalent to sequential, reviewable interaction, and their accessibility is unverified.
- **No automatic capability check establishes screen-reader usability.** Backend readiness and observed accessibility must remain separate.

The user’s requirement stands: configured defaults must be **actual current editable values in both rich and linear modes**. No pending-default `/submit` substitute is recommended. If the chosen mode/backend cannot provide the required editor on the selected streams, report **interaction unavailable** rather than silently changing the behavior.

## Contract context

The shared contract, grammar ticket, glossary and editing ticket were read. They establish:

1. Linear interaction means sequential, reviewable questions and answers—not merely “not full-screen.”
2. Rich and linear interactions require equivalent task outcomes.
3. Defaults are initially editable and erasable; erasing means empty, subject to validation.
4. EOF does not submit a partial answer or default.
5. Prompt output defaults to stderr; stdout remains application-owned.
6. Input-source changes, pipe consumption and controlling-terminal access require explicit policy.
7. `/help` and `/cancel` are exact whole-line commands; quoting and paste provenance have specified semantics.
8. Neither mode is presumed accessible without exact-environment testing.

These are requirements, **not evidence that an existing backend satisfies them**.

## Mechanism comparison

| Mechanism | Evidence for editable initial text | Main unresolved constraint |
|---|---|---|
| Dart cooked `readLineSync()` | No initial-text API | Cannot meet prefill requirement by itself |
| POSIX canonical terminal input | No standardized prefill API | Native erase/kill is not a general initial-value editor |
| Windows `ReadConsoleW` + control structure | Documented initial buffer preservation | Verify editing/display and chosen-stream behavior per host |
| GNU Readline through native integration | Explicit editable buffer and startup hooks | Packaging, signals, redisplay, stream ownership, accessibility |
| libedit/editline integration | Native application-managed editing APIs | Exact initialization and macOS build behavior require investigation |
| Dart TUI editor | Editable text component evidence; strongest explicit setter evidence found in `artisanal` | Exact package/API, cursor rendering, reviewability and accessibility |
| Custom Dart editor | Feasible by design, not an existing capability claim | Trelis owns decoding, editing, rendering, lifecycle and verification |

### 1. Dart stdin: useful transport, not an initial-value editor

The official `Stdin` API exposes `lineMode`, `echoMode`, terminal detection, byte reads, stream reads and `readLineSync()`. Its documented `readLineSync` signature has encoding and line-terminator options, **not initial text**. Disabling `lineMode` changes delivery behavior; it does not create a text editor. [1]

Crucially, `readLineSync()` returns already-read characters when EOF occurs; only EOF before any characters returns `null`. Consequently, a non-null result alone cannot distinguish a properly terminated submission from an unterminated final fragment. A backend implementing Trelis’s EOF rule needs explicit framing/termination information rather than treating every returned string as submitted. [1]

**Inference:** an editor can be implemented using Dart’s input APIs, or accessed through native integration, but that is an additional subsystem—not a feature supplied by `readLineSync()`.

### 2. POSIX cooked input: editing is limited and prefill is not standardized

The POSIX General Terminal Interface defines canonical input, line delimiters, erase, kill and EOF processing. It does not define a general operation that installs an initial editable string into the canonical input buffer. Terminal output and terminal input processing are separate concerns. [2]

**Implications:**

- Writing `Name: Alice` does not make `Alice` part of the line being read.
- Standard canonical processing does not promise shell-style cursor movement, completion, arbitrary mid-line editing or portable initial-value injection.
- Linux/macOS support for a terminal does not establish a common prefill mechanism.

Linux `TIOCSTI` injects input bytes, but is nonportable and security-restricted: the Linux man-pages documentation describes restrictions introduced in Linux 6.2 involving `CAP_SYS_ADMIN` and the `dev.tty.legacy_tiocsti` setting. It is not a suitable general capability foundation. [3]

**Recommendation:** do not make terminal-input injection the default backend. In addition to portability/security problems, injected bytes risk confusing user input, default state, command recognition and paste provenance.

### 3. Windows cooked input: a concrete native candidate, not yet an end-to-end result

Microsoft documents:

- `ReadConsole` reads a console input buffer using console input modes.
- It fails when its input handle is redirected to a file or pipe.
- `CONSOLE_READCONSOLE_CONTROL.nInitialChars` specifies the number of initial characters to preserve in the supplied buffer; it must be smaller than the requested read capacity.
- The control structure requires the Unicode form of `ReadConsole`. [4][5]

This is substantially stronger prefill evidence than Dart’s standard API offers. It identifies an API intended to retain existing input-buffer content while further input is read.

**Not established by this research:** that simply supplying the buffer produces exactly Trelis’s required visible initial text, cursor location, deletion behavior, correction flow and reviewable transcript across Windows Console Host, Windows Terminal and pseudoterminal environments.

Output ownership is particularly important. Console echo follows console behavior; passing Trelis’s desired stderr stream elsewhere does not itself prove that native echo and editing use that same destination. Microsoft’s console mode documentation also makes line input, echo and processed control input distinct settings. [6]

**Recommendation:** prototype on the inherited input handle and explicitly selected output arrangement. Do not open `CONIN$`, `CONOUT$` or another terminal as an implicit repair. Treat failure or an incompatible stream arrangement as unavailable, not as permission to change input sources.

### 4. Application-managed native editors

#### GNU Readline

GNU Readline’s library API supplies the missing application-level mechanism:

- `rl_startup_hook` and `rl_pre_input_hook` provide initialization hooks.
- `rl_insert_text()` inserts into the current editable line.
- `rl_replace_line()` replaces line contents.
- Cursor state and redisplay functions are exposed.
- `rl_instream` and `rl_outstream` allow input/output stream selection. [7]

Readline **8.3** has a first-party release announcement dated July 2025. The manual URL is rolling, so an implementation must pin the actual library/build rather than infer the deployed version from that URL. [8]

Readline is an application-managed editor, not POSIX cooked-line prefill. It brings its own key bindings, terminal preparation, redisplay, signal handling and EOF conventions. Those must be reconciled with Trelis’s result and lifecycle contract. [7]

A single active Readline line could be a candidate for sequential interaction if completed exchanges remain reviewable. **That is an architectural inference, not an accessibility finding.** Readline compatibility does not prove screen-reader compatibility.

#### libedit/editline

The FreeBSD primary manual documents `el_push()` for pushing input and facilities such as `EL_GETCFN` for custom character acquisition. It is evidence of another application-managed native editor family, not a POSIX canonical-input facility. [9]

This research did **not** establish a version-pinned, macOS-specific prefill recipe or verify the deployed system library’s behavior. Do not assume that macOS’s presence of a similarly named library makes arbitrary editline recipes portable.

A native-library approach also requires separate dependency, distribution, licensing and integration review.

### 5. What the Dart TUI evidence actually establishes

Two packages must not be conflated.

**`dart_tui` 2.1.0**

The package’s versioned documentation describes `TextInputModel` as a single-line editor with cursor support, character limits, validation, masking and completion. Its changelog documents editing keys including start/end and word movement. It also offers alternate-screen operation and an inline cursor widget. [10]

However, this research **did not retrieve definitive version-pinned constructor/setter source establishing the exact initial-value assignment API**. Search results for `setValue` led to another package. Do not prescribe an unverified `TextInputModel(value: ...)` constructor or claim that a placeholder is editable initial text.

**`artisanal`**

The primary API documentation explicitly exposes `TextInputModel.setValue(String)`, `setText(...)`, and cursor `position`; `setText` is documented as replacing text and placing the cursor at the end. The package versions page listed **0.6.2** during research. The inspected API link is rolling and should be replaced with a pinned version/source reference before implementation. [11][12]

This is concrete evidence that an application-managed Dart text editor can provide programmable current text and cursor state. It is **not evidence that its normal renderer qualifies as Trelis linear interaction**, that its defaults preserve every required character, or that it works accessibly in any selected environment.

**Next source-level check:** download the exact package archive, inspect setter implementation and key-update/render paths, then build a minimal editor. Decoder tests and README feature lists are insufficient.

## Responsibilities an editor backend must own

A backend offering editable defaults must account for more than displaying a string.

### Text and input state

- Store current text independently of placeholder/help text.
- Initialize it before the first user editing action.
- Preserve deletion to empty, including after failed validation.
- Define cursor movement and deletion over Unicode, combining sequences and wide characters.
- Handle wrapping, pasted newlines, multiline state and resizing.
- Distinguish explicit submission from EOF and interruption.

A single-line proof does not establish feasibility for Multiline, masks, structured segments or secrets.

### Keys and grammar

Apply the shared command/literal grammar **at its defined submission boundary**, not as global printable-key shortcuts.

An additional integration question needs a component decision: if an initial editable value is exactly `/cancel` or `/help`, how is that value represented without accidentally executing the command on Enter? The grammar already guarantees arbitrary literal entry through quoting and caller-supplied-answer bypass, but configured **initial editor content** is not automatically the same thing as a caller-supplied final answer.

Do not silently insert visible quoting into the configured value or silently bypass command recognition. Establish the provenance/representation rule explicitly and test it.

Native cooked input generally supplies line data without bracketed-paste provenance. Identical typed/pasted bytes cannot be reliably distinguished after that information is lost. Application-managed editors must deliberately retain identified-paste provenance when available; lack of framing must retain the documented grammar behavior.

### Output and lifecycle

A candidate linear editor should keep prior questions, submitted answers and validation messages reviewable, avoid clearing them, and finish with a stable transcript. An inline renderer that repeatedly erases earlier output does not qualify merely because it avoids the alternate screen.

It must also:

- Use the selected prompt output stream.
- Avoid ANSI/cursor control on redirected output.
- Restore terminal settings and handlers after all supported exits.
- Avoid competing readers of the same input.
- Reconcile native echo, application echo and physical cursor position.
- Handle Ctrl+C both as key input and process-level interruption.
- Never replay secrets through errors, summaries or debugging.

These are proposed acceptance responsibilities derived from the contract, **not claims about existing package behavior**.

## Capability detection and redirected streams

A useful capability model is more specific than `isTerminal`:

1. **Input policy:** interactive source, explicit line-source opt-in or supplied answers?
2. **Backend availability:** native library/API present and usable?
3. **Required editor operations:** initial text, cursor movement, deletion, correction and required multiline/paste behavior?
4. **Output compatibility:** selected destination supports the backend’s rendering/echo requirements?
5. **Lifecycle readiness:** mode changes and cleanup supported?
6. **Verification status:** tested environment or explicitly unverified?

Dart terminal flags and Windows `GetConsoleMode` can contribute to the first checks; neither establishes all six. [1][6]

**Recommended policy:**

- Preflight the chosen mode **with the actual prompt’s needs**, including configured defaults.
- Do not equate “linear” with “can always fall back to `readLineSync`.”
- An opted-in pipe can supply explicit lines, but does not make the user’s initial value interactively editable.
- Supplied answers remain a separate caller policy, not a silent default acceptance path.
- Redirected prompt output must remain stable text. If a backend requires cursor addressing or native console echo incompatible with that destination, declare it unavailable.
- Never seek a controlling terminal or consume a redirected input source implicitly.

Automatic selection can choose only among genuinely capable options; it cannot convert an unsupported requirement into another interaction.

## Screen-reader evidence and limits

NV Access’s user guide documents console support and review of console text. Its **2025.3** guide distinguishes classic Windows Console UI Automation settings from Windows Terminal; these are not interchangeable environments. The rolling guide identified itself as 2026.3 during research. [13]

That evidence supports including these environments in a test matrix. It does **not** establish that prefilled text, simulated cursors, native cooked editing or any Dart TUI widget is announced correctly.

No primary evidence found here establishes end-to-end Trelis task completion with:

- NVDA or JAWS in the proposed Windows configurations;
- VoiceOver in macOS Terminal;
- Orca in Linux terminal emulators.

These remain **unverified**, not proven incompatible. Reviewability of the final transcript is necessary but does not establish usable editing, cursor announcements or correction.

## Minimum follow-up experiments

Perform these as explicit experiments, not production implementation.

### A. Windows native initial-buffer probe

Use `ReadConsoleW` and `nInitialChars` with inherited handles. Record OS build, terminal host/version, console modes and handle types.

Test visible initial text, cursor location, Home/End/arrows, insertion, backspace, delete-all then Enter, Unicode, wrapping, cancellation, Ctrl+C, validation retry, input termination and repeated prompts. Inspect output routing with stdout redirected, stderr redirected and selected alternate streams. Include Console Host and Windows Terminal; test any pseudoterminal environment separately.

### B. POSIX native editor probe

Pin a Readline build on Linux and macOS; separately investigate a pinned macOS libedit build if desired. Seed the actual buffer through documented APIs, select streams explicitly and keep transcript output intact.

Test the same editing/lifecycle tasks plus TERM variations, resizing, signals, bracketed paste and input/output redirection. Confirm no hidden controlling-terminal opening.

### C. Dart editor probe

Pin `dart_tui` 2.1.0 and inspect its actual initial-value API; separately pin the relevant `artisanal` release. Exercise initial text, cursor state and deletion directly.

Then determine whether an inline presentation can preserve completed exchanges without screen clearing or rewriting prior content. If not, the normal renderer may be a rich candidate but is not established as a linear backend.

### D. Contract and accessibility probe

Include initial values `""`, `/cancel`, `/help`, backslash-prefixed paths, trailing spaces, combining characters, emoji and over-width text. Verify exact preservation, command collisions, paste provenance and partial EOF.

With experienced screen-reader users, test discovery of the initial value, mid-value correction, erasure, error recovery, help/cancel and transcript review. Record exact terminal, reader, OS, settings and backend versions.

**Decision gate:** claim support only for combinations that satisfy backend requirements and observed keyboard/screen-reader tasks. Until then, report candidate mechanisms and explicit unverified scope.

## Primary sources

1. Dart SDK API: [Stdin](https://api.dart.dev/dart-io/Stdin-class.html), [readLineSync](https://api.dart.dev/dart-io/Stdin/readLineSync.html), [lineMode](https://api.dart.dev/dart-io/Stdin/lineMode.html). Rolling documentation.
2. The Open Group, POSIX.1-2024: [General Terminal Interface](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap11.html).
3. Linux man-pages: [TIOCSTI](https://man7.org/linux/man-pages/man2/TIOCSTI.2const.html).
4. Microsoft Learn: [ReadConsole](https://learn.microsoft.com/en-us/windows/console/readconsole).
5. Microsoft Learn: [CONSOLE_READCONSOLE_CONTROL](https://learn.microsoft.com/en-us/windows/console/console-readconsole-control).
6. Microsoft Learn: [GetConsoleMode](https://learn.microsoft.com/en-us/windows/console/getconsolemode), [SetConsoleMode](https://learn.microsoft.com/en-us/windows/console/setconsolemode).
7. GNU: [Readline Library manual](https://www.gnu.org/software/readline/manual/readline.html), especially programming, variables, utility functions and signal handling.
8. GNU Readline maintainer: [Readline 8.3 release announcement](https://lists.gnu.org/archive/html/bug-readline/2025-07/msg00004.html).
9. FreeBSD: [editline(3), 16.0-CURRENT](https://man.freebsd.org/cgi/man.cgi?manpath=FreeBSD+16.0-CURRENT&query=editline&sektion=3). Not a macOS compatibility assertion.
10. Package author: [`dart_tui` 2.1.0](https://pub.dev/packages/dart_tui/versions/2.1.0), [changelog](https://pub.dev/packages/dart_tui/changelog), [repository](https://github.com/codenameakshay/dart_tui).
11. Package author: [`artisanal` TextInputModel API](https://pub.dev/documentation/artisanal/latest/bubbles/TextInputModel-class.html).
12. Package author: [`artisanal` versions](https://pub.dev/packages/artisanal/versions).
13. NV Access: [NVDA 2025.3 User Guide](https://download.nvaccess.org/releases/2025.3/documentation/userGuide.html), [rolling User Guide](https://api.nvaccess.org/documentation/userGuide.html).