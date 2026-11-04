# Terminal keyboard capabilities and cross-platform conflicts

- **Ticket:** Terminal keyboard capabilities and cross-platform conflicts
- **Project:** Trelis
- **Report path:** `docs/research/trelis-keyboard.md`
- **Research date:** 2026-11-03 (host local date, UTC−05:00).
- **Status:** Primary-source research complete; implementation and platform validation not performed.
- **Scope:** Keyboard interaction for Windows, macOS and Linux, legacy and modern terminals, including keyboard and screen-reader usability across the 39 in-scope atlas specimens. StepperForm is excluded. This report proposes candidates, not final interaction requirements.

## Executive findings

1. **No universal terminal key-event model exists.** Traditional terminal input is a byte stream with intentional collisions: Tab/Ctrl+I, Enter/Ctrl+M, and Escape/Ctrl+[ cannot reliably be distinguished. Escape also prefixes other keys. Enhanced protocols can reduce ambiguity, but only with end-to-end support. [1][2]
2. **Common keys are useful conventions, not unconditional delivery guarantees.** Arrows, Home/End, Delete, Backspace and Shift+Tab have documented encodings, but terminal modes, profiles, operating-system shortcuts and intermediaries affect what arrives. [1][3][4]
3. **Ctrl+C crosses the boundary between input and process control.** POSIX signal processing and Windows processed-input mode can prevent an application from receiving it as an ordinary key. Cleanup must work for the actual cancellation path. [5][6]
4. **Text entry and shortcut recognition must remain separate concepts.** Layouts, AltGr/Option, dead keys, IMEs and multi-code-point text make “one key equals one character” unsafe. Grapheme editing and terminal cell width are separate problems. [2][7][8]
5. **Keyboard operability does not establish screen-reader accessibility.** VoiceOver and Narrator have their own keyboard commands and interaction modes. Successfully decoding input says nothing about announcement order, focus, changing content or recovery. [9][10]
6. **The repository’s prototype evidence is narrow and explicitly qualified.** It documents selected Windows scenarios using locally patched Dart TUI 3.0.0, not a shipped cross-platform or screen-reader guarantee. The archived implementation was not inspected in this research session. [L1]

**Recommendation:** evaluate a conservative line-oriented fallback, a conventional interactive tier, and explicitly negotiated enhancements. Treat accessibility evidence as a separate axis, not the highest keyboard tier.

## Evidence classification and method

- **Documented:** supported by the linked platform documentation, terminal specification, official manual or language documentation.
- **Repository-reported evidence:** described in the checked-out repository’s documentation, but not independently rerun here.
- **Inference/recommendation:** this report’s reasoning; not a specification imposed on Trelis.
- **Unperformed validation:** any actual terminal, operating-system, clipboard, IME, SSH, multiplexer or assistive-technology experiment.

Live web search was available and used to locate primary sources. Some search results exposed only partial page content. This report consequently avoids treating snippets as exhaustive conformance evidence, avoids asserting that a current release implements every documented feature, and pins a Unicode revision rather than relying on the moving “latest” page.

No shell, write or git tools were available to this researcher. The parent reports having created:

- Worktree: `C:/Users/bvlou/projects/trelis-research-keyboard`
- Branch: `research/trelis-keyboard`
- Starting revision: `bd5a19f`

The parent must save and commit this report. No commit hash is claimed here.

## 1. Input layers and why compatibility varies

A useful analytical model is:

> keyboard/layout/IME → OS and assistive technology → terminal emulator → optional SSH/multiplexer → terminal driver and application input API → decoder → prompt semantics

This is a **reasoning model**, not a promised implementation architecture.

Documented examples of transformations or interception include:

- POSIX terminal flags can translate carriage return, perform canonical editing, generate signals and implement software flow control. [5]
- Windows console mode flags determine line input, echo, processed input and VT input behavior. [6]
- Apple Terminal profiles can configure Option-as-Meta and function-key mappings. [4]
- tmux has prefix bindings, escape timing and extended-key settings. [11]
- SSH has its own escape commands in sessions with a pseudo-terminal. [12]
- Screen readers interpret some keyboard combinations themselves. [9][10]

**Inference:** “Windows support” or “ANSI support” is too coarse a claim. The relevant unit is a tested combination of terminal, configuration, input API, intermediary chain and assistive technology.

## 2. Key-by-key findings

| Key or action | Documented facts | Candidate use and caveats |
|---|---|---|
| **Enter** | Traditional encodings overlap with Ctrl+M; POSIX can translate CR to NL. Microsoft documents VT input mappings. [2][3][5] | Strong submission convention, but multiline entry and paste require explicit handling. Do not offer Enter and Ctrl+M as distinct legacy commands. |
| **Escape** | Legacy Escape overlaps with Ctrl+[ and prefixes escape sequences. Kitty documents this ambiguity; tmux exposes `escape-time`. [2][11] | Useful cancel/back candidate, but decoding requires an explicit ambiguity strategy. Do not interpret a partially received sequence as cancellation prematurely. |
| **Ctrl+C** | POSIX `ISIG` can generate SIGINT. Windows `ENABLE_PROCESSED_INPUT` handles Ctrl+C rather than placing it in the normal input buffer. [5][6] | Strong interruption convention. Model cancellation independently of whether it arrives as a key or signal/control event. Confirm restoration after each supported route. |
| **Tab** | Tab and Ctrl+I collide in legacy input. [2] | Candidate next-field/completion action, with a declared policy when both exist. Do not require a distinct Ctrl+I action. |
| **Shift+Tab** | Terminfo provides the back-tab capability; xterm documents reverse-tab behavior. [1][13] | Candidate reverse traversal, not a universal prerequisite. Provide another discoverable route if unavailable. |
| **Arrows** | xterm and Microsoft document cursor-key sequences; normal/application cursor modes differ. [1][3] | Strong interactive-tier candidates. Decode supported mode variants rather than a single assumed byte string. |
| **Home/End** | Terminfo describes terminal-specific key capabilities; terminal profiles can remap keys. [4][13] | Useful beginning/end candidates, with alternate bindings or explicit actions. Do not assume identical bytes or physical-key availability everywhere. |
| **Backspace** | xterm documents configurable backarrow behavior; terminfo describes `kbs`. [1][13] | Accept expected BS/DEL variants where appropriate. A raw DEL byte is not automatically the physical forward-Delete key. |
| **Delete** | xterm and Windows VT documentation define distinct editing-key sequences. [1][3] | Candidate delete-forward action. It should not be the only way to correct text. |
| **Function keys** | xterm and Windows document sequences; Apple Terminal allows custom mappings. [1][3][4] | Optional accelerators only until delivered-key behavior is validated. Avoid making completion or cancellation depend solely on them. |

### Escape timing

**Documented:** legacy Escape is ambiguous; tmux itself may wait to classify it. [2][11]

**Inference:** adding an application timeout introduces another latency and correctness trade-off, especially over remote connections. Neither an aggressively short timeout nor waiting indefinitely is universally correct.

**Validation needed:** split sequences across reads, delayed bytes, nested tmux, remote latency, and a genuine Escape immediately followed by text. A parser must also preserve incremental UTF-8 decoding; read boundaries are not key boundaries.

## 3. Editing conventions, modifiers and chords

### Word and line editing

GNU Readline documents familiar Emacs-style movement and editing:

- Ctrl+A / Ctrl+E: beginning/end of line.
- Meta+B / Meta+F: backward/forward word.
- Meta+D: delete forward by word.
- Meta+Backspace: delete backward by word.
- Ctrl+K / Ctrl+U: kill toward line boundaries.
- Ctrl+Y: yank killed text. [14]

These are **Readline conventions**, not terminal requirements. Readline is configurable; they do not prove that every shell, terminal prompt or user expects the same bindings.

**Candidate alternatives:**

- Keep character-by-character editing usable independently of word shortcuts.
- Consider familiar word/line accelerators as optional bindings.
- Define “word” explicitly for the input domain. Shell-style words, Unicode word boundaries, paths and identifiers are not interchangeable.
- Do not advertise kill/yank bindings unless their actual semantics, including any kill ring, are implemented.

### Alt, Option and Meta

Apple Terminal documents a profile-specific “Use Option as Meta key” setting. [4] Kitty’s protocol documentation describes legacy encoding limitations and enhanced modifier reporting. [2]

**Inference:** a mandatory Alt-letter shortcut can conflict with text entry on non-US layouts, and Option-as-Meta can change how a user types characters. An application cannot assume all Option presses are shortcuts.

Recommendations:

- Avoid mandatory Alt/Option, Ctrl+Alt or Command/Super bindings.
- Test AltGr text entry rather than treating every reported Ctrl+Alt combination as a command.
- Treat Escape-then-key alternatives as optional conventions with their own Escape ambiguity.
- Preserve layout-produced text instead of deriving it solely from a US physical-key map.

### Control ambiguity and interception

Legacy control encodings collapse combinations that would be distinct in GUI applications. Kitty documents examples including Tab/Ctrl+I and Enter/Ctrl+M, and the limitations of distinguishing modified ordinary keys. [2]

POSIX software flow control may consume Ctrl+S/Ctrl+Q. Signal-generating keys depend on terminal settings. [5]

**Recommendation:** do not make Ctrl+S, Ctrl+Q, Ctrl+Z, Ctrl+\, Ctrl+[ or colliding Ctrl+letter combinations the only path to essential actions.

### Key chords

Readline supports multi-key commands and keyboard macros; tmux uses prefix bindings. [11][14] These establish that sequential chords are possible, not universally discoverable.

**Recommendation:** do not depend on simultaneous key-state tracking in the baseline byte-stream model. Use sequential chords, if any, as optional accelerators with help, cancellation and recovery. Avoid conflicting with multiplexer prefixes.

## 4. Keyboard layouts, IME and Unicode

### Layouts and composition

Kitty’s enhanced protocol can report associated text and, in applicable modes, text without corresponding key information. Its documentation explicitly discusses OS-, layout- and IME-dependent behavior. [2]

This does **not** establish a cross-terminal API for composition start/update/end, candidate-window management or preedit text.

**Inference and candidates:**

- Treat committed text as text, not a series of shortcut opportunities.
- Avoid assuming a printable key produces exactly one code point.
- Avoid rejecting input because no physical-key identity is available.
- Do not bind Enter/Escape behavior during composition based only on assumptions from ordinary typing.
- Investigate candidate-window placement and cancellation on real IMEs.

**Unperformed validation:** Japanese, Chinese and Korean IMEs; dead-key accents; compose sequences; AltGr; non-Latin layouts; right-to-left text.

### Graphemes and display width

Dart documents `String` as UTF-16 code units, runes as Unicode code points, and `characters` for extended grapheme clusters. [7] Unicode UAX #29 revision 45 defines Unicode 16.0 text segmentation, including extended grapheme clusters. [8]

**Recommendation:** evaluate grapheme-aware cursor movement, deletion and user-facing length limits. Do not equate:

1. bytes,
2. UTF-16 code units,
3. code points,
4. grapheme clusters,
5. terminal display columns.

**Inference:** grapheme-aware editing alone cannot establish correct cursor placement. Rendering width and terminal behavior need separate validation.

Test combining marks, supplementary-plane characters, variation selectors, emoji modifiers, ZWJ emoji, flags and mixed-direction text. Specify the Unicode data/version used by the chosen implementation.

## 5. Clipboard and bracketed paste

xterm documents bracketed-paste mode:

- Enable: `CSI ? 2004 h`
- Disable: `CSI ? 2004 l`
- Start delimiter: `CSI 200 ~`
- End delimiter: `CSI 201 ~` [1]

GNU Readline documents treating bracketed paste as a unit rather than interpreting its contents as ordinary editing commands. [14]

Windows Terminal documents configurable actions, including clipboard actions. [15] Clipboard shortcuts belong partly to the terminal, not necessarily to the application.

**Recommendations:**

- Let users paste using their terminal’s mechanisms; do not require one universal clipboard shortcut.
- Treat supported bracketed paste as text input, not a batch of navigation/submission commands.
- Define newline, tab, control-character and size-limit policies separately from ordinary typing.
- Handle delimiters split across reads and interrupted paste.
- Restore any modes enabled by the application.
- Keep literal escape/control bytes from becoming unintended commands.
- Avoid claiming paste provenance when the input stream provides none.

**Unknown:** in a terminal without paste delimiters, typed and pasted identical bytes may be indistinguishable. Automatic submission of pasted newlines therefore needs a deliberate risk decision.

**Repository evidence boundary:** the archived notes report bracketed-paste **protocol injection**, not an OS clipboard test. [L1]

## 6. SSH, tmux and terminal capability detection

### SSH

OpenSSH documents escape commands when a pseudo-terminal is allocated; the default escape character is `~`, recognized at the beginning of a line, with commands such as `~.` to disconnect. [12]

**Inference:** even apparently ordinary text can have upstream session semantics. Applications cannot guarantee delivery of every physical key.

### tmux

tmux documents:

- `escape-time`;
- extended-key handling;
- terminal feature declarations including extended keys;
- its own command bindings and prefixes. [11]

**Recommendation:** validate the complete chain. A supporting outer terminal does not prove that an application inside tmux receives the same protocol.

### Detection limits

Terminfo describes key capabilities, while Dart exposes terminal-related APIs such as `lineMode`, `echoMode` and `supportsAnsiEscapes`. [13][16]

**Inference:** none of these alone proves support for enhanced keyboard reporting, bracketed paste, a particular clipboard shortcut or screen-reader accessibility. `TERM`, OS name and ANSI capability are evidence inputs, not comprehensive capability guarantees.

Any active negotiation needs bounded response handling and graceful fallback. Unsupported or malformed responses must not corrupt user text.

## 7. Optional enhanced keyboard protocols

### Kitty keyboard protocol

The protocol documents progressive enhancements including disambiguation, event types, alternate key identities and associated text, along with mode query and stack mechanisms. It provides distinct encodings for combinations that legacy protocols collapse. [2]

**Candidate:** use negotiated enhancements to improve decoding without making them a prerequisite for essential interactions.

Do not assume:

- every modern terminal supports it;
- every intermediary forwards it;
- release events are always available;
- enabling one enhancement enables all others;
- enhanced reporting exposes full IME composition;
- enhanced keys improve screen-reader output.

### xterm modified-key reporting

xterm documents `modifyOtherKeys` and related keyboard controls. [1]

**Candidate:** evaluate it as another enhancement, but do not treat all modified-key protocols as interchangeable. Pin modes and expected encodings in tests.

### Windows native events

Microsoft’s `KEY_EVENT_RECORD` exposes key-down state, repeat count, virtual-key/scan codes, character data and control-key state. Windows also provides VT input mode. [3][6][17]

**Inference:** native console events can offer information absent from legacy bytes, but that does not prove a Dart backend exposes it, nor that remote PTY input retains it. Native API availability is not implementation evidence for Trelis.

## 8. Screen-reader conflicts and accessibility boundary

VoiceOver uses a modifier, ordinarily Control+Option or Caps Lock, and documents a command for passing the next keypress through. [9] Narrator’s scan mode uses keyboard navigation and has its own mode toggle. [10]

**Inference:** essential prompt actions should not depend exclusively on combinations normally used by assistive technology. Requiring users to disable a screen reader is not an acceptable substitute for validating interaction.

Keyboard research cannot settle:

- whether prompt labels and help are announced;
- whether changing selection is announced once and in order;
- whether errors and disabled choices are understandable;
- whether cursor movement or repainting creates excessive speech;
- whether input remains understandable with echo disabled;
- whether cancellation restores a usable session.

**Recommendation:** assess keyboard delivery and screen-reader usability separately. Include native terminal/assistive-technology combinations and Linux screen-reader coverage in a dedicated validation matrix. This research establishes no supported screen-reader combination.

## 9. Candidate capability tiers—not final requirements

| Candidate tier | Candidate behavior | Evidence needed |
|---|---|---|
| **A. Line-oriented fallback** | Sequential textual prompts, explicit choices, Enter submission; avoid reliance on cursor-addressed focus and Escape-only recovery. | Redirected input behavior, EOF, cancellation, validation loops, text output and screen-reader reading order. |
| **B. Conventional interactive** | Arrows, conventional edit keys, optional Tab/back-tab, robust Escape decoding, optional bracketed paste and correct terminal restoration. | Real Windows/macOS/Linux terminal matrix, delayed/split sequences, alternate encodings, actual clipboard, narrow terminals and accessibility testing. |
| **C. Negotiated enhanced input** | Optional disambiguation and richer key/text events with conventional fallback. | Exact terminal and multiplexer versions, negotiation, unsupported responses, restoration and equivalent essential actions without enhancements. |

These tiers describe **candidate input capability groupings**, not increasing accessibility guarantees.

**Open design issue:** some visual specimens may not have a direct line-oriented equivalent. Research should identify semantic alternatives for all 39 in-scope specimens rather than silently dropping them or assuming a full-screen interaction is mandatory.

## 10. Existing repository evidence and its limits

The inspected `docs/terminal-backend.md` states that:

- Dart TUI is an implementation direction, not an unqualified cross-platform guarantee.
- The evaluated dependency was **locally patched Dart TUI 3.0.0**.
- Unpatched 3.0.0 failed exact Windows line/echo restoration after Escape and Ctrl+C.
- The patch changed initialization order so the original console flags were saved before Dart echo/line changes.
- Six Windows scenarios covered Input, Select and MultiSelect cancellation paths, with two sessions per scenario and console-state comparisons.
- Bracketed-paste tests injected the protocol.
- macOS/Linux, actual clipboard, Unicode/display width and accessibility remained outstanding. [L1]

The documentation identifies archive commit:

`8483a5a343bb595fdbeb3b3b5881e5233c285e90`

and upstream archive SHA-256:

`3612ecfdb0bd6fe1f653a8268585943c9daf366698d1d1b6e889ba9b47b59fcb`

**Not inspected:** archived source, patch implementation, archived test files, upstream release history or whether an equivalent fix has since shipped. No git execution was available. These repository statements must remain attributed evidence, not independent verification.

## 11. Decisions and validation tasks for the map

No human decisions were made by this research.

### Decisions to schedule

1. Define the minimum compatibility envelope and fallback policy.
2. Decide cancellation semantics and required terminal restoration guarantees.
3. Decide how completion, field traversal and multiline entry share Tab/Enter.
4. Select optional editing conventions and define word semantics.
5. Set paste newline/control/limit policies.
6. Choose grapheme and display-width policy, including versioning.
7. Decide whether enhanced protocols justify negotiation complexity.
8. Define assistive-technology acceptance evidence independently of keyboard decoding.

### Validation tasks

- Inventory the 39 in-scope specimens’ essential actions; exclude StepperForm explicitly.
- Test local Windows console/Windows Terminal, macOS terminals and Linux terminals, recording exact versions, shell, layout and settings.
- Include a legacy/basic environment and redirected/non-TTY input.
- Test direct, SSH, tmux and nested combinations.
- Exercise every key family in this ticket, including ambiguity, modifiers, repeated keys and delayed/split input.
- Test actual clipboard paste separately from synthetic delimiter injection.
- Test IMEs, dead keys, AltGr, non-US layouts and grapheme/display-width cases.
- Validate screen-reader operation, announcement quality and recovery on each claimed combination.
- Verify terminal-mode restoration after success, validation failures, Escape, Ctrl+C, signals, exceptions and repeated sessions.
- Inspect archived tests and the exact dependency revision before adopting their conclusions.
- Verify any claimed upstream restoration fix by source comparison and regression testing.

## Sources

All external references below are primary sources. Moving documentation pages were consulted as documentation, not as proof of conformance by an installed release.

1. **xterm, Control Sequences** — key encodings, modes, modified keys and bracketed paste.  
   <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>  
   **xterm manual** — configurable keyboard/backarrow behavior.  
   <https://invisible-island.net/xterm/manpage/xterm.html>

2. **Kitty, Comprehensive keyboard handling in terminals** — legacy limitations, progressive enhancements, associated text and IME discussion.  
   <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>

3. **Microsoft, Console Virtual Terminal Sequences** — Windows VT input and cursor/editing keys.  
   <https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences>

4. **Apple, Change Profiles Keyboard settings in Terminal on Mac** — Option-as-Meta and key mappings.  
   <https://support.apple.com/guide/terminal/trmlkbrd/mac>

5. **Linux man-pages, termios(3)** — canonical input, signals, CR translation and flow control. Linux-specific documentation; not used as proof of identical defaults on macOS.  
   <https://man7.org/linux/man-pages/man3/termios.3.html>

6. **Microsoft, SetConsoleMode** — Windows console input flags and Ctrl+C processing.  
   <https://learn.microsoft.com/en-us/windows/console/setconsolemode>

7. **Dart, Built-in types: Runes and grapheme clusters** — UTF-16, code points and user-perceived characters.  
   <https://dart.dev/language/built-in-types#runes-and-grapheme-clusters>

8. **Unicode UAX #29, revision 45, Unicode 16.0.0, 2024-08-28** — pinned segmentation reference, not a claim about the latest release.  
   <https://unicode.org/reports/tr29/tr29-45.html>

9. **Apple, VoiceOver keyboard control and pass-through**.  
   <https://support.apple.com/guide/voiceover/control-your-mac-with-keyboard-commands-vo2681/mac>  
   <https://support.apple.com/guide/voiceover/vo2722/mac>

10. **Microsoft Support, Narrator: Chapter 3, Using scan mode**.  
    <https://support.microsoft.com/en-us/accessibility/windows/narrator/chapter-3-using-scan-mode>

11. **OpenBSD, tmux(1)** — escape timing, bindings and extended-key options. Version-sensitive; pin the tested release later.  
    <https://man.openbsd.org/tmux.1>

12. **OpenBSD/OpenSSH, ssh(1)** — PTYs and escape commands.  
    <https://man.openbsd.org/ssh.1>

13. **ncurses, terminfo(5)** — key capability names and terminal-dependent sequences.  
    <https://invisible-island.net/ncurses/man/terminfo.5.html>

14. **GNU Bash/Readline manual** — movement, killing/yanking, configurable bindings, macros and bracketed paste.  
    <https://www.gnu.org/software/bash/manual/html_node/Readline-Movement-Commands.html>  
    <https://www.gnu.org/software/bash/manual/bash.html>

15. **Microsoft, Windows Terminal Actions** — configurable terminal actions and clipboard bindings.  
    <https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions>

16. **Dart API, Stdin** — terminal input controls and ANSI support property. SDK version was not pinned in this research.  
    <https://api.dart.dev/dart-io/Stdin-class.html>  
    <https://api.dart.dev/dart-io/Stdin/lineMode.html>  
    <https://api.dart.dev/dart-io/Stdin/echoMode.html>  
    <https://api.dart.dev/dart-io/Stdin/supportsAnsiEscapes.html>

17. **Microsoft, KEY_EVENT_RECORD** — native Windows keyboard-event structure.  
    <https://learn.microsoft.com/en-us/windows/console/key-event-record-str>

**[L1] Local repository documentation:** `docs/terminal-backend.md`, read from `C:/Users/bvlou/projects/prompty`. Its historical test and patch claims were not independently reproduced.