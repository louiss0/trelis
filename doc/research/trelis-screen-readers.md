# Screen-reader access and nonvisual terminal interaction

Research date: **2026-11-03 (host local date, UTC−05:00)**  
Scope: Trelis standalone prompts and feedback; all 39 atlas specimens except `StepperForm`.  
Status: research findings and candidate validation work—not an approved interaction specification.

## Executive finding

Screen-reader support is a property of the **whole environment**: application output and input handling, terminal accessibility implementation, operating system, assistive technology, configuration, and user workflow. Terminal escape-sequence support does not demonstrate usable speech output.

Primary documentation establishes relevant capabilities:

- NVDA documents terminal output announcements, review, and Windows Terminal-specific configuration and limitations.[1]
- Apple explicitly documents VoiceOver use in Terminal.[2]
- Microsoft documents Narrator text-reading commands; Windows Terminal's first-party accessibility engineering document describes its UI Automation event mechanisms.[3][4]
- GNOME documents Orca review commands, and VTE exposes accessibility interfaces.[5][6]

None of these sources establishes that Trelis, its archived prototype, Dart TUI, or all combinations of these environments are accessible. **No terminal, screen-reader, keyboard, password, or restoration tests were performed for this report.**

The strongest candidate for broad compatibility is an explicitly selectable **linear interaction path**, alongside—not necessarily replacing—a richer interactive presentation. This is a recommendation requiring design decisions and validation, not an already approved fallback or proof of universal access.

## 1. Evidence and limits

### Evidence categories used here

- **Documented capability:** a primary source describes a particular feature or behavior.
- **Inference:** reasoning about implications for Trelis; not a measured result.
- **Recommendation:** a candidate requirement or design direction.
- **Unperformed validation:** behavior that must be checked in actual environments.

External research used live web search against primary documentation. Some sources are rolling documentation or repository `main` pages rather than immutable revisions. Search results exposed relevant documentation excerpts; this investigation did not execute the documented features.

Local context reviewed:

- `doc/theme-components.md`: 40 named atlas specimens, of which `StepperForm` is excluded here; runtime trials covered only Input/TextInput, Select, and MultiSelect.
- `docs/issues/trelis-accessible-prompts/map.md`: research precedes design; broad compatibility, keyboard and screen-reader usability are required; no interaction decision is already resolved.

The atlas's static HTML and visual specimens are not evidence of terminal accessibility. Existing backend direction and restoration-patch history must not be treated as shipped accessibility functionality.

## 2. Documented platform capabilities

| Environment | Primary-source finding | What it does not establish |
|---|---|---|
| NVDA and Windows terminals | The NVDA 2025.3 guide documents dynamic-content announcements, console support settings, and separate Windows Terminal output handling.[1] | That every redraw or prompt change is announced clearly, once, and in a useful order. |
| Narrator and Windows Terminal | Narrator documents reading by line and other text units.[3] Windows Terminal's accessibility engineering document discusses UIA text events and notifications containing output text.[4] | End-to-end Narrator usability for Trelis widgets; complete parity with NVDA. |
| VoiceOver and Apple Terminal | Apple explicitly documents using VoiceOver to hear Terminal text and navigate with the VoiceOver cursor.[2] | Announcement behavior for redraw-heavy menus, passwords, alternate screens, or every macOS version. |
| Orca and a VTE-based terminal | Orca documents flat review of visible window contents; VTE GTK 4 documents `Gtk.Accessible` and `Gtk.AccessibleText` interfaces.[5][6] | That a particular GNOME Terminal/VTE/Orca combination makes every dynamic prompt usable. |
| Other terminals | iTerm2 has first-party terminal documentation; this search did not locate a dedicated VoiceOver behavior guide there.[7] | Absence of documentation is not evidence of absent support. Other emulators remain validation candidates. |

### Windows: important distinctions

The NVDA guide distinguishes Windows Console support configuration from Windows Terminal configuration. Its console UIA/legacy setting should not be generalized to Windows Terminal.[1]

For Windows Terminal, NVDA documents alternative new-text strategies, including diffing and UIA notifications. The guide describes limitations associated with notification-based reporting, including password-character exposure and potentially inaccurate long-output reporting.[1] This is especially important: “supports accessibility notifications” is not equivalent to “safe and correct for every prompt.”

NVDA also exposes user-controlled dynamic-content reporting and progress-bar output settings.[1] An application cannot assume that the user's configuration will automatically speak every update.

Microsoft's Windows Terminal engineering document discusses the development of accessibility event handling and output-notification behavior.[4] It is valuable architectural evidence, but it is a document named for 2023 on a moving branch—not a release-specific acceptance statement for a currently installed terminal.

### macOS

Apple's Terminal accessibility guide provides direct evidence that VoiceOver can be used with Terminal.[2] This is stronger than assuming macOS accessibility extends automatically to terminal applications.

Apple also documents configurable audible and visual bells.[8] Consequently, a bell is not a dependable sole confirmation or error channel. It can be disabled or configured differently, and it conveys little semantic detail.

The reviewed Apple documentation does not settle automatic announcement behavior during cursor-addressed redraws. That remains a manual validation question.

### Linux

Orca's flat review provides line-, word-, and character-oriented review of visible content. GNOME documents that this is a flattened view and describes refreshing review when contents change.[5] It should not be mistaken for a guarantee of continuous semantic tracking of an interactive terminal widget.

VTE's accessibility interfaces establish an implementation path from terminal content to toolkit accessibility.[6] They do not establish that Orca receives application-level concepts such as “selected option,” “validation error,” or “progress bar” from arbitrary text and ANSI sequences.

**Inference:** Linux validation must record the terminal and VTE/toolkit versions, not only “Linux with Orca.”

## 3. Output and interaction strategies

The following are **recommendations and inferences**, unless explicitly attributed to a source.

### 3.1 Prefer stable, meaningful text over visual state reconstruction

For a standalone prompt, make the following recoverable as text:

1. Prompt label and purpose.
2. Expected input or available commands.
3. Current value, choice, or selection state.
4. How to confirm, cancel, obtain help, or correct an answer.
5. Validation result and any next action.

Do not require a user to infer state from color, indentation, a moving highlight, or an unexplained symbol.

Candidate example:

```text
Deployment region
Choose a number, or type cancel.
1. Europe
2. North America
3. Asia Pacific
Current choice: Europe
Choice:
```

This is an illustrative linear interaction, not a selected Trelis contract. Large option sets, localization, ambiguous names, and repeated use require additional design.

For richer arrow-key interaction, consider a compact textual update such as `Current choice: North America, 2 of 3`. Whether it is spoken reliably and without excessive repetition must be tested.

### 3.2 Redraw and cursor movement

Microsoft documents cursor movement, erasure, and alternate-screen operations as terminal display controls.[9] These are not accessibility semantics.

**Inference:** repainting a full prompt on each keypress can produce missing, repeated, stale, or verbose announcements depending on terminal and screen-reader behavior. The exact failure mode is not established without tests.

Candidate safeguards:

- Limit redraw to the smallest meaningful change.
- Avoid repeatedly repainting labels and long instructions.
- Keep a stable reading order.
- Preserve a useful final answer or outcome in ordinary output.
- Do not require cursor-position recognition to identify the active choice.
- Offer a mode that does not depend on cursor-addressed updates.

Minimal redraw is not automatically accessible either: an update that changes only one character may be difficult to interpret out of context.

### 3.3 Alternate screen and scrollback

Microsoft documents that the alternate screen buffer has no scrollback and is distinct from the main buffer.[9]

**Inference:** alternate-screen use can remove a familiar review/history mechanism and leave little useful transcript after exit. This does not prove that screen readers cannot access alternate-screen applications.

Recommendation: do not make an alternate screen a prerequisite for standalone prompts. If retained as an option, validate reading, review, resizing, suspension, exit, and the final main-buffer transcript independently.

### 3.4 Errors

Candidate error output should identify:

- The affected prompt.
- What is invalid.
- How to correct it, where known.
- Whether the entered value has been retained.
- Where interaction resumes.

For example:

```text
Port: enter a whole number from 1 to 65535.
The previous value is still available for editing.
```

Do not use only a red border, bell, or generic `Invalid` marker. Do not repeat a secret value in an error.

Errors should remain reviewable rather than disappear after a brief animation or timeout. Speech interruption, duplicate output, and correction-loop behavior require manual checks.

### 3.5 Passwords and sensitive input

Dart exposes input echo control; that is a terminal input feature, not a guarantee that assistive technology will never speak sensitive input.[10] NVDA explicitly documents password-speaking behavior and relevant terminal settings.[1]

Recommendations:

- State that input is hidden.
- Never print the secret in a summary, validation error, debug message, or accessibility-oriented transcript.
- Decide deliberately whether mask characters or character counts disclose information; do not assume they are harmless.
- Preserve editing, cancellation, and completion without depending on visible masking.
- Treat echo restoration after success, cancellation, EOF, and exceptions as a separate correctness requirement.
- Do not silently switch a redirected password source to ordinary visible input.

**Unperformed validation:** verify application echo, terminal output events, screen-reader typing echo, clipboard/paste behavior, transcripts, and restoration together. Tests involving secrets should use disposable test strings, not actual credentials.

### 3.6 Dynamic feedback, progress, and motion

NVDA's documented progress settings concern progress information recognized by NVDA; an ASCII bar or spinner is not thereby guaranteed to be exposed as a native accessible progress control.[1]

Candidate strategy:

- Announce a meaningful start message.
- Prefer phase changes or coarse milestones to frame-by-frame output.
- Include textual completion, cancellation, and failure.
- For concurrent work, include the task name in each update.
- Avoid unbounded repeated lines.
- Provide a nonanimated presentation and an explicit verbosity policy.
- Do not let a quiet mode remove essential error or completion information.

For example:

```text
Uploading archive.
Upload: 50 percent.
Upload complete.
```

The update cadence is a design question. This report does not prescribe a universal interval.

Reduced motion and reduced speech noise overlap but are different needs. Removing animation does not necessarily eliminate repeated announcements; reducing announcements must not remove necessary state.

### 3.7 Color and symbol dependence

Candidate requirement: all actionable distinctions must survive monochrome output and uncertain symbol pronunciation.

Use text such as `selected`, `not selected`, `unavailable`, and `error` where needed. A check mark or color can supplement that meaning but should not be the only representation.

ASCII is a useful compatibility option, not proof of accessibility: repeated punctuation can also be noisy or ambiguous when spoken.

## 4. Linear, plain, and non-TTY operation

These are separate capabilities:

- **No color:** removes color dependence.
- **No animation:** removes motion or periodic visual updates.
- **Plain rendering:** avoids cursor addressing and decorative control sequences.
- **Linear interaction:** uses sequential, reviewable questions and answers.
- **Noninteractive operation:** obtains values without an interactive conversation.

One switch need not imply all five.

Dart documents separate input and output terminal checks and describes ANSI support detection as best effort.[10][11] Neither `hasTerminal` nor ANSI support detects screen-reader usability.

Recommendations:

1. Test input and each relevant output stream separately.
2. Do not assume terminal output means terminal input is interactive.
3. When output is redirected, avoid cursor controls and animated progress in that stream.
4. When input is redirected or reaches EOF, do not hang indefinitely waiting for interactive keys.
5. Do not silently select destructive or consequential defaults.
6. Keep machine-readable output separate from conversational prompts and diagnostics where the application provides such a contract.
7. Define how callers supply explicit values or request noninteractive failure.
8. Provide an explicit user override for a linear presentation; do not rely exclusively on screen-reader detection.

Whether prompts belong on stderr, and whether opening a controlling terminal is ever allowed, require caller-facing policy. This research does not approve either behavior.

## 5. Coverage of all 39 in-scope specimens

The grouping below is a research coverage checklist, not a proposed API or decision to consolidate specimens.

| Specimens | Candidate nonvisual representation and validation concern |
|---|---|
| `TextInput`, `NumberInput` | Stable label, format constraints, current/default value, editing and correction. |
| `Password` | Hidden-entry instruction, safe confirmation, no secret replay, echo restoration. |
| `Multiline` | Explicit completion/cancellation method; distinguish newline insertion from submission; review and correction of earlier lines. |
| `MaskedInput`, `RegexInput`, `URLInput`, `EmailInput`, `PortInput`, `IPAddressInput` | Explain accepted syntax and validation errors in text; do not rely on positional highlighting or placeholder punctuation alone. |
| `DateInput`, `TimeInput`, `DurationInput`, `CronInput` | State format, units, interpretation and relevant timezone; offer text entry rather than requiring spatial segment navigation. |
| `PathInput`, `FilePicker`, `DirectoryPicker` | Recoverable current path, entry type, navigation and selection; textual path entry candidate; distinguish empty directory, unavailable path and permission failure. |
| `Autocomplete`, `SearchSelect`, `CommandPalette`, `TimezoneSelect` | Distinguish query text, match count, active result and accepted value; avoid announcing all results on every keystroke. |
| `Confirm`, `Checkbox`, `Radio`, `Toggle`, `Select` | Explicit state and default; understandable alternatives; no dependence on a highlighted row. |
| `MultiSelect`, `TagInput` | Distinguish active item from selected items; announce additions/removals and provide a reviewable selection summary. |
| `TreeSelect` | State level/path, expanded/collapsed status and selection; candidate linear traversal or path-based alternative. |
| `Slider`, `RangeSlider` | Numeric value, bounds, units and step; for a range, identify the endpoint being changed; candidate direct numeric entry. |
| `SortableSelect` | Item identity, current position and resulting order; candidate explicit move commands or ordered textual input. |
| `ColorInput` | Textual color value and accepted format; no reliance on the swatch. |
| `Keypress`, `KeyChordInput` | Screen-reader and terminal shortcut interception; discoverable cancellation; avoid requiring unavailable or reserved chords. |
| `Text` | Logical reading order, reviewable content, no decoration-only meaning. |
| `Progress`, `Spinner`, `MultiSpinner` | Named operations, bounded updates, completion/failure and nonanimated output. |

**Count:** 39 specimens. `StepperForm` is intentionally excluded.

Every family needs both keyboard-only and screen-reader tasks. A successful `Select` experiment cannot validate `TreeSelect`, `SortableSelect`, password handling, or progress.

## 6. Web accessibility: useful analogy, not terminal certification

WCAG 2.2 supplies useful principles: keyboard access, non-color cues, labels/instructions, textual errors, status messages, and control over nonessential animation.[12]

Useful analogies include:

- Labels and instructions before input.
- Explicit selected/checked/expanded state.
- Distinguishing focus from selection.
- Errors associated with the affected input.
- Status updates without forcing the user away from their current task.

However:

- Printing `role=alert` or an ARIA label does not create web accessibility semantics in a terminal.
- An ANSI menu is not automatically an ARIA listbox.
- DOM focus models, `aria-live`, and web keyboard patterns do not establish terminal event delivery.
- Web-browser or static-atlas accessibility tests do not validate terminal speech behavior.
- WCAG-inspired recommendations here are not a claim of terminal WCAG conformance.

A web pattern can inform a design hypothesis. The terminal implementation still needs an independently specified contract and actual verification.

## 7. Candidate verification environments

These are **proposed environments, not tested or promised support tiers**.

| Candidate | Purpose |
|---|---|
| Windows 11, Windows Terminal, PowerShell, NVDA | Windows Terminal output announcements, review, password and redraw behavior. |
| Windows 11, Windows Terminal, PowerShell, Narrator | Independent Windows screen-reader path. |
| Windows Console Host, Command Prompt or Windows PowerShell, NVDA | Legacy/varied Windows behavior; do not substitute Windows Terminal results. |
| Current supported macOS, Apple Terminal, VoiceOver | First-party documented Terminal/VoiceOver combination. |
| macOS, iTerm2, VoiceOver | Representative alternative terminal; support remains to be established. |
| Supported GNOME distribution, GNOME Terminal/VTE, Orca | Linux accessibility stack and visible-text review. |
| Additional terminal, SSH, and multiplexer combinations | Broad-compatibility expansion after initial evidence; record each additional transport/layer. |

The map should choose precise versions and coverage expectations later. Record OS build, terminal version, shell, screen-reader version, verbosity and echo settings, keyboard layout, locale, Dart/backend revision, and any multiplexer or remote session.

## 8. Manual verification protocol

No steps below were executed in this investigation.

1. **Baseline:** verify ordinary shell output, typing, line review and scrollback before launching a specimen.
2. **Initial prompt:** can the tester discover the label, purpose, default, instructions and cancellation without sight?
3. **Operation:** complete the task using keyboard and speech; distinguish application cursor, screen-reader review cursor and selected value.
4. **Review:** recover current state and prior instructions after exploration, scrolling and returning from help.
5. **Errors:** enter invalid input, hear and review the error, correct it, and confirm retained state.
6. **Dynamic output:** assess missing, stale, duplicate, excessive and interrupted announcements—not merely whether sound occurred.
7. **Secrets:** use disposable strings; inspect audible echo and recorded output; verify echo restoration.
8. **Lifecycle:** test confirmation, cancellation, EOF, interruption, resize and exceptional exit.
9. **Fallbacks:** repeat relevant tasks with linear/no-animation/no-color settings, mixed TTY/redirection combinations and input exhaustion.
10. **Transcript:** inspect redirected bytes for escape sequences, secrets, misleading partial progress and missing outcomes.

Use blind or experienced screen-reader participants for usability evaluation; sighted listening alone cannot establish practical nonvisual usability. Keep sanitized transcripts and precise observations. Distinguish “tester completed with workaround” from “intended interaction worked.”

Do not collect real secrets or publish recordings containing sensitive input.

## 9. Decisions and validation tasks for the map

This report resolves no human interaction decision. Suggested follow-up work:

1. **Select a provisional environment matrix and evidence vocabulary.** Separate desired support, documented capability, observed behavior, and known limitations.
2. **Decide the fallback contract.** Determine whether explicit linear interaction is required for every applicable specimen, and specify how users and callers select it.
3. **Prototype announcement strategies.** Compare stable linear output, minimal redraw and richer redraw in real screen-reader sessions.
4. **Specify state vocabulary.** Labels, active versus selected state, hierarchy, ordering, errors and final summaries need explicit contracts.
5. **Investigate password safety separately.** Include NVDA reporting strategies and user echo settings; do not equate hidden terminal echo with complete secrecy.
6. **Specify dynamic feedback policy.** Set progress granularity, concurrent-task naming, completion/error guarantees and reduced-motion behavior.
7. **Specify non-TTY behavior.** Cover independent stream redirection, EOF, defaults, machine output and absence of an interactive terminal.
8. **Verify backend lifecycle behavior at an exact revision.** In particular, do not assume the Windows restoration patch is shipped.
9. **Create per-specimen acceptance tasks.** Use the 39-specimen checklist above; identify where an alternative interaction or further experiment is needed.
10. **Expand beyond the initial matrix deliberately.** Include legacy terminals, SSH/multiplexers, narrow windows, multilingual text and alternative terminal implementations as evidence and resources permit.

Open questions are settled by exact-version documentation where available, reproducible platform experiments, and nonvisual user evaluation—not by ANSI capability detection or the existing Dart TUI direction alone.

## Sources

1. **NV Access, NVDA 2025.3 User Guide** — fixed release documentation; terminal support, Windows Terminal new-text reporting, password settings, dynamic content and progress output.  
   https://download.nvaccess.org/releases/2025.3/documentation/userGuide.html

2. **Apple, Use macOS accessibility features in Terminal on Mac** — rolling OS-selected documentation; VoiceOver use in Terminal.  
   https://support.apple.com/guide/terminal/trml1020/mac

3. **Microsoft Support, Narrator: Chapter 4—Reading text** — rolling Windows documentation; text-reading commands.  
   https://support.microsoft.com/en-us/accessibility/windows/narrator/chapter-4-reading-text

4. **Microsoft Windows Terminal repository, `doc/terminal-a11y-2023.md`** — first-party engineering document on rolling `main`; not a pinned release guarantee.  
   https://github.com/microsoft/terminal/blob/main/doc/terminal-a11y-2023.md

5. **GNOME Orca Help, Flat Review; Flat Review Commands** — rolling help; visible-content review and navigation.  
   https://help.gnome.org/orca/howto_flat_review.html  
   https://help.gnome.org/orca/commands_flat_review.html

6. **GNOME VTE, GTK 4 `Vte.Terminal` API documentation** — rolling generated API documentation; accessibility interfaces.  
   https://gnome.pages.gitlab.gnome.org/vte/gtk4/class.Terminal.html

7. **iTerm2, Documentation** — first-party documentation index; consulted as a representative alternative terminal, not evidence of verified VoiceOver behavior.  
   https://iterm2.com/documentation.html

8. **Apple, Change Profiles Advanced settings in Terminal on Mac** — rolling OS-selected documentation; configurable audible and visual bell.  
   https://support.apple.com/guide/terminal/trmladvn/mac

9. **Microsoft Learn, Console Virtual Terminal Sequences** — cursor/display controls and alternate-screen behavior.  
   https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences

10. **Dart API, `Stdin`** — rolling SDK API documentation; terminal detection, line mode and echo control.  
    https://api.dart.dev/dart-io/Stdin-class.html  
    https://api.dart.dev/dart-io/Stdin/hasTerminal.html  
    https://api.dart.dev/dart-io/Stdin/echoMode.html

11. **Dart API, `Stdout` and ANSI support detection** — rolling SDK API documentation; output capability checks are not accessibility checks.  
    https://api.dart.dev/dart-io/Stdout-class.html  
    https://api.dart.dev/dart-io/Stdin/supportsAnsiEscapes.html

12. **W3C, Web Content Accessibility Guidelines 2.2 and Understanding documents** — web accessibility principles used here only as analogies, not terminal conformance evidence.  
    https://www.w3.org/TR/WCAG22/  
    https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html  
    https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html  
    https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html  
    https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html  
    https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html