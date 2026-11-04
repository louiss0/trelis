# Component interaction precedents and Dart TUI feasibility

- **Research date:** 2026-11-03
- **Ticket:** Component interaction precedents and Dart TUI feasibility
- **Project:** Trelis, a Dart terminal prompt library
- **Baseline:** `bd5a19f`
- **Scope:** All 39 atlas specimens other than `StepperForm`; research only, not component implementation or public API design.
- **Prepared for:** `docs/research/trelis-component-feasibility.md`
- **Evidence status:** Local atlas and backend decision inspected; selected archived files inspected through parent-extracted copies; live web searches performed against primary sources. No platform, terminal, clipboard, or assistive-technology tests performed during this research.

## Executive findings

1. **The atlas is a visual inventory, not an interaction specification.** Its generator depicts states and hints for 40 named specimens, using 15 structural grammars across 45 themes. Excluding `StepperForm` leaves the 39 specimens traced below. Some hints depend on key combinations that are not reliably distinguishable in legacy terminal input. [L1–L3, T1]
2. **Dart TUI provides relevant building blocks, not established coverage of all specimens.** Its API documents keyboard and paste messages, resize events, single-line and multiline editing, selection models, custom views, and terminal lifecycle management. These are useful feasibility evidence; they do not establish Trelis semantics, broad terminal compatibility, or screen-reader usability. [D1–D7]
3. **The strongest local implementation evidence remains narrow:** archived trials of Input/TextInput, Select, and MultiSelect using locally patched Dart TUI 3.0.0. The local decision document reports Windows-console scenarios, repeated sessions, protocol-injected paste, and restoration checks. That is neither a 39-component implementation nor cross-platform accessibility validation. [L2, A1–A4]
4. **The Windows restoration patch must remain an explicit dependency gate.** Inspection confirms that the archived patch calls `enableWindowsVtInput()` before changing Dart echo/line modes. This research could not confirm an equivalent fix in a currently published upstream release. An upstream issue concerning enabling VT input is related but does not prove preservation of the original console-mode snapshot. [A1, A2, D8, T2]
5. **Interaction precedents can be grouped without fixing the public API.** Editing, candidate navigation, committed selection, validation, cancellation, and feedback have overlapping requirements. Filesystem browsing, schedule interpretation, reordering, and shortcut capture introduce additional domain and protocol constraints.
6. **Keyboard support is necessary but insufficient for accessibility.** No inspected source establishes an accessibility semantics bridge from Dart TUI models to platform assistive technology. A conservative linear-output mode and explicit state words are recommendations to evaluate, not already chosen solutions or guarantees.

## 1. Evidence and limits

### 1.1 Local sources inspected

| ID | Source | What it establishes |
|---|---|---|
| L1 | [`../theme-components.md`](../theme-components.md) | Exact specimen names, atlas counts, distinction between component/structure/theme, and limited runtime trial coverage. |
| L2 | [`../terminal-backend.md`](../terminal-backend.md) | Recorded backend direction, patch provenance, reported prototype outcomes, and remaining evaluation. |
| L3 | [`../../example/prototype-themes/generate.py`](../../example/prototype-themes/generate.py), especially `COMPONENTS`, `specimen()`, and `vocabulary()` | Actual specimen text, depicted state, key hints, and ASCII/Unicode alternatives. These are static generated pictures, not functioning controls. |

The generator was inspected directly rather than treating component names as sufficient evidence of intended interaction. For example, it depicts `Checkbox` as two independent items, `RangeSlider` as two endpoints, `DirectoryPicker` with separate open/select actions, and `KeyChordInput` as a sequence of modified keystrokes. Those details matter to subsequent design. [L3]

### 1.2 Archived evidence inspected

The parent extracted the following complete files from exact commit `8483a5a343bb595fdbeb3b3b5881e5233c285e90` to a temporary read-only research location. Their contents were inspected; the extraction and tests were not performed by this research agent.

| ID | Archived path at that commit | Inspection result |
|---|---|---|
| A1 | `third_party/dart_tui/PROMPTY_PATCH.md` | Describes the original defect, one-file ordering patch, package archive provenance, and reported verification. |
| A2 | `third_party/dart_tui/lib/src/program.dart` | Confirms patched raw-mode ordering, release/restore methods, shutdown restoration, and `finally` cleanup in the main run loop. |
| A3 | `pubspec.yaml` | Confirms a local-path **dev dependency** on `third_party/dart_tui`; `dart_console`, `ffi`, and `win32` also occur in experimental dev dependencies. It does not establish production dependencies. |
| A4 | `test/prototype_dart_tui_interactions_windows.ps1` | The complete suite entry point was available; inspected excerpts establish aggregation and the “All 6 real-console interaction scenarios passed” success message. The message is conditional script output, not evidence of a fresh execution. |

**Evidence limitation:** The individual scenario scripts, prototype component implementations, native Windows helper implementation, and full selected upstream test bodies were not independently inspected here. Detailed historical outcome claims below are attributed to the archived patch notes and local backend decision, not presented as newly reproduced findings.

### 1.3 External-source limitations

Live searches reached official package documentation, upstream issue material, standards, and first-party library documentation. However:

- Indexed pub.dev material was inconsistent: some results exposed 3.0.0 package material, while version/changelog results described 2.1.0 as latest or did not list 3.0.0.
- `latest` API URLs are mutable and were not resolved to a verified release archive during this research.
- No current upstream source revision was retrieved that establishes `_setRawMode` ordering equivalent to the local patch.
- Search summaries of API documentation are useful discovery evidence, but not a substitute for reviewing a pinned implementation before adoption.

Consequently, this report distinguishes **documented API availability** from **verified behavior of a particular dependency revision**. It does not declare the current upstream version, a shipped restoration fix, or compatibility based on package platform badges.

## 2. Primary external sources

### Dart TUI

- **D1 — Package and repository:**  
  <https://pub.dev/packages/dart_tui>  
  <https://github.com/codenameakshay/dart_tui>
- **D2 — Library API inventory:**  
  <https://pub.dev/documentation/dart_tui/latest/dart_tui/>  
  <https://pub.dev/documentation/dart_tui/latest/>
- **D3 — `TextInputModel`:** single-line model, cursor, character limits, validation, echo modes, suggestions, styling, and model updates.  
  <https://pub.dev/documentation/dart_tui/latest/dart_tui/TextInputModel-class.html>
- **D4 — Message hierarchy:** keyboard, paste, and other terminal messages.  
  <https://pub.dev/documentation/dart_tui/latest/dart_tui/Msg-class.html>
- **D5 — Resize message:**  
  <https://pub.dev/documentation/dart_tui/latest/dart_tui/WindowSizeMsg-class.html>
- **D6 — Program lifecycle API:**  
  <https://pub.dev/documentation/dart_tui/latest/dart_tui/Program-class.html>
- **D7 — Changelog:** additional feature documentation, including focus reporting; subject to the version inconsistency described above.  
  <https://pub.dev/packages/dart_tui/changelog>
- **D8 — Upstream Windows input issue #4:** reports missing VT-input enablement; closed with reference to #6. This is not confirmation of the local restoration-order fix.  
  <https://github.com/codenameakshay/dart_tui/issues/4>
- **D9 — Archived evaluated package:**  
  <https://pub.dev/packages/dart_tui/versions/3.0.0>  
  <https://pub.dev/api/archives/dart_tui-3.0.0.tar.gz>  
  Archive SHA-256 recorded locally: `3612ecfdb0bd6fe1f653a8268585943c9daf366698d1d1b6e889ba9b47b59fcb`. This hash was not recalculated here.

### Actual terminal-library precedents

- **P1 — GNU Bash manual, Readline Interaction:** cursor editing, insertion/deletion, and Enter accepting the entire line.  
  <https://www.gnu.org/software/bash/manual/html_node/Readline-Interaction.html>
- **P2 — prompt_toolkit 3.0.52, Asking for input:** multiline editing, password masking, completion, validation, and submission conventions. Multiline Enter inserts a newline; Meta+Enter or Escape followed by Enter submits.  
  <https://python-prompt-toolkit.readthedocs.io/en/stable/pages/asking_for_input.html>
- **P3 — prompt_toolkit reference:** configurable key bindings, completers, validators, and editing modes.  
  <https://python-prompt-toolkit.readthedocs.io/en/stable/pages/reference.html>
- **P4 — InquirerPy select:** keyboard navigation and multiselect behavior, including Space toggling and Enter submission.  
  <https://inquirerpy.readthedocs.io/en/latest/pages/prompts/list.html>
- **P5 — InquirerPy key bindings and fuzzy selection:** configurable bindings and searchable-choice precedent.  
  <https://inquirerpy.readthedocs.io/en/stable/pages/kb.html>  
  <https://inquirerpy.readthedocs.io/en/latest/pages/prompts/fuzzy.html>

These are precedents from real terminal libraries, not requirements to reproduce their interfaces or exact bindings.

### Terminal and accessibility sources

- **T1 — Kitty keyboard protocol:** explains limitations of legacy keyboard encoding and richer negotiated keyboard reporting.  
  <https://sw.kovidgoyal.net/kitty/keyboard-protocol/>
- **T2 — Microsoft console input modes and VT sequences:** documents native mode flags and terminal input sequences.  
  <https://learn.microsoft.com/en-us/windows/console/getconsolemode>  
  <https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences>
- **T3 — Apple, accessibility in Terminal:** platform-specific terminal accessibility context.  
  <https://support.apple.com/en-ae/guide/terminal/trml1020/mac>
- **T4 — Apple VoiceOver, progress/status changes:** announcements are affected by assistive-technology configuration. This does not establish equivalent behavior for arbitrary repainted terminal text.  
  <https://support.apple.com/guide/voiceover/learn-about-progress-or-status-changes-vo14110/mac>

### Web/GUI analogies, not terminal guarantees

- **W1 — WAI-ARIA APG, Developing a Keyboard Interface:** focus versus selection, visible focus, composite navigation, and disabled-control considerations.  
  <https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/>
- **W2 — APG Combobox:** useful vocabulary for editable text plus suggestions and popup navigation.  
  <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/>
- **W3 — APG introduction:** scope and implementation context of ARIA authoring practices.  
  <https://www.w3.org/WAI/ARIA/apg/about/introduction/>

APG concerns web widgets, DOM focus, and accessibility semantics. A terminal rendering of a tree, checkbox, or combobox does not inherit those roles, announcements, or accessibility-tree relationships.

## 3. Cross-cutting interaction findings

### 3.1 Focus, candidate, selection, and submission are different states

The atlas sometimes uses color/highlight for the active row and separate markers for selected items. The distinction should survive monochrome rendering. [L3]

Actual terminal precedent supports navigating independently of multiselect toggling and submitting later. [P4] APG provides useful terminology for distinguishing focus from selection, but its browser mechanisms do not transfer automatically. [W1]

**Research recommendation:** Later specifications should distinguish:

- keyboard editing position or active item;
- highlighted suggestion or candidate;
- committed selected value or set;
- submitted answer;
- disabled/unavailable item;
- pending asynchronous result.

Whether single-choice movement immediately changes a provisional value, how Escape rolls back it, and whether disabled items are focusable remain decisions. The local prototype skipped disabled choices using an enabled-only model mapping; that is historical evidence, not an approved rule for every component. [L2]

### 3.2 Editing should not accidentally trigger selection or commands

Readline establishes a familiar terminal-editing precedent, and prompt_toolkit demonstrates completion and validation alongside editable input. [P1–P3] Printable-key shortcuts suitable for a non-editable list can conflict with SearchSelect, Autocomplete, TagInput, or CommandPalette typing.

**Recommendation:** Specify input ownership and mode transitions explicitly. Pasted text should be treated as data, not replayed as individual navigation, acceptance, or cancellation gestures. Historical protocol-injection tests are encouraging but do not prove real clipboard behavior. [L2]

### 3.3 Submission and cancellation require compatible alternatives

The atlas proposes Alt+Enter for Multiline, Ctrl+Enter for directory selection, Ctrl+arrows for reordering, and captured modified keys. [L3] Legacy protocols cannot represent every physical key/modifier combination distinctly; extended protocols require terminal support and appropriate negotiation. [T1]

Therefore:

- Do not make an unverified modified key the only way to finish an operation.
- Distinguish Escape as menu dismissal, value clearing, sequence cancellation, or whole-prompt cancellation.
- Define Ctrl+C interruption separately from choosing “No” or an empty value.
- Define EOF/non-interactive handling rather than assuming a key stream always exists.
- Provide discoverable alternatives for navigation-versus-action conflicts.

These are design recommendations; this research does not choose final bindings.

### 3.4 Validation has several independent layers

Dart TUI exposes single-line validation facilities; prompt_toolkit demonstrates validator/completer separation. [D3, P2, P3] Neither supplies every domain policy implied by the atlas.

Later specifications should distinguish:

1. editable intermediate text;
2. syntactic parsing;
3. semantic constraints;
4. optional environment checks;
5. submission eligibility;
6. asynchronous validation state.

Examples: a syntactically valid path need not exist or be writable; a valid URL need not be reachable; a port number need not be available; an email address need not be deliverable.

**Recommendation:** Preserve the user's input on failure, show a textual explanation, identify whether checking is pending, and prevent stale asynchronous results from overwriting newer edits. These are inferred requirements, not validated backend behavior.

### 3.5 Feedback-only components do not need artificial focus

`Text`, `Progress`, `Spinner`, and `MultiSpinner` depict information rather than editable answers. [L3] Cancellation of the underlying job is a separate application responsibility.

**Recommendation:** Evaluate explicit textual status, stable task identifiers/order, retained failure details, completion summaries, reduced animation, and rate-limited updates. Frequent redraws may be visually attractive but their speech behavior is unvalidated. Apple documents configurable progress announcements in its own accessibility system; that does not prove spinner output will be announced appropriately. [T3, T4]

### 3.6 Discoverability must survive without visual decoration

The atlas's helper lines are valuable evidence of intended discoverability. [L3] However, a dim hint, colored error, hidden hover affordance, or animation is insufficient as the only representation of an action or state.

**Recommendation:** Evaluate:

- a short initial action hint;
- an explicit way to discover additional actions;
- textual state words and counts;
- ASCII/monochrome output;
- a linear transcript-oriented interaction mode;
- actionable empty, no-match, loading, and error states.

Whether these are selected automatically, configured by users, or exposed as separate operating modes is open. No reliable screen-reader detection mechanism was established by this research.

## 4. Dart TUI feasibility and constraints

| Area | Documented or inspected evidence | What remains unproven |
|---|---|---|
| Keyboard messages | API includes keyboard message types, including press/release distinctions. [D2, D4] | Which physical combinations arrive under each terminal/protocol; reliable use of release events; terminal/OS shortcut interception. |
| Paste | API exposes `PasteMsg`; local notes report bracketed-paste protocol injection. [D2, D4, L2] | OS clipboard paths, terminal-specific paste behavior, Unicode normalization policy, and safe behavior when bracketed paste is unavailable. |
| Single-line editing | `TextInputModel` documents limits, validation, echo modes, suggestions, and cursor facilities. [D3] | Grapheme-aware limits, exact deletion behavior, width handling, masking leakage, undo expectations, and all Trelis-specific editing policies. |
| Multiline editing | `TextAreaModel` appears in the API inventory. [D2] | Needed editing features, scrolling, wrapping, submission alternatives, large text, and accessibility in the pinned version. |
| Choice models | `SelectListModel` and `MultiSelectModel` are documented; multiselect documentation describes toggling and confirmation. [D2] | Stable IDs, disabled-item policy, filtering preservation, result order, and exact scrolling behavior needed by Trelis. |
| Rendering | Custom `View` output and cursor/terminal metadata are documented; local trials used custom views. [D1, D2, L2] | Narrow layouts, scrollback, long lists, ambiguous-width characters, combining sequences, emoji, and terminal differences. |
| Resize | `WindowSizeMsg` reports dimensions. [D5] | Correct reflow, cursor preservation, minimum-size behavior, and resize during asynchronous updates. |
| Focus reporting | Terminal `FocusMsg`/`BlurMsg` and opt-in reporting are documented. [D4, D7] | Not a widget-focus system or accessibility focus bridge; behavior depends on terminal reporting. |
| Lifecycle | `Program` has run, terminal release/restore, and quit controls. Archived code restores raw mode in shutdown and uses run-loop `finally` cleanup. [D6, A2] | Restoration under every failure path, suspend/resume, external processes, abrupt termination, and concurrent-output interference. |
| Screen readers | No inspected Dart TUI source establishes semantic accessibility exposure. | Actual usability and announcements for each supported terminal/screen-reader combination. |
| Complex controls | Editing, messages, and custom rendering can be composition substrates. | No verified turnkey implementation for the full filesystem, schedule, range, reorder, or shortcut semantics in this ticket. |

“Can be composed” is an engineering inference, not proof that a complete component is easy, accessible, or compatible.

### 4.1 Windows restoration: exact finding

Archived patched `Program._setRawMode(true)` calls `enableWindowsVtInput()` before:

```dart
stdin.echoMode = !raw;
stdin.lineMode = !raw;
```

On leaving raw mode it calls the platform restoration helpers. Shutdown invokes `_setRawMode(false)`. [A2]

The archived notes explain that unpatched 3.0.0 saved the Windows mode only after the Dart setters had cleared echo/line flags, producing:

```text
before=503:1 after=497:1
```

The missing `0x0006` corresponds to line-input and echo-input flags; Microsoft documents those flags. [A1, T2]

**Current upstream equivalent: unconfirmed.** Issue #4 concerns enabling VT input, not necessarily when the original flags are captured. Its closure does not prove the local ordering fix is shipped. [D8]

**What would settle this:**

1. Resolve an exact candidate release and immutable source/archive.
2. Inspect raw-mode setup ordering and the save/restore helper.
3. Compare behavior with the archived patch.
4. Run exact original/final native-mode and cursor checks, including repeated sessions, normal submit, Escape, Ctrl+C, and error exits.
5. Record package version, archive hash or commit, terminal host, Windows version, and observed results.

No local patch should be removed based solely on a changelog, platform badge, or related issue closure.

## 5. Traceability: all 39 specimens

**Reading the table:** Atlas observations come from `specimen()` in [L3]. “Precedent” identifies actual terminal precedents unless marked **analogy**. “Gap/open decision” describes research-derived implementation or policy questions, not approved requirements. `StepperForm` is intentionally excluded.

| # | Specimen and observed atlas state/hint | Precedent and feasible substrate | Gap / open decision |
|---:|---|---|---|
| 1 | **TextInput** — project name with cursor; Enter continues. | Readline line editing [P1]; Dart TUI single-line editor [D3]. | Required/empty/default semantics; grapheme limits; editing bindings; cancellation and final transcript. |
| 2 | **Password** — masked token; “hidden / paste supported.” | Password masking in prompt_toolkit [P2]; echo modes in `TextInputModel` [D3]. | Masked versus no-echo mode; length disclosure; paste/control handling; no secret in errors, logs, or submitted summaries. Actual clipboard behavior untested. |
| 3 | **NumberInput** — `0` invalid for 1–16; default 4. | Text editing plus validation [D3, P2]. | Integer/decimal grammar, signs, locale, intermediate invalid states, bounds, and whether adjustment keys supplement typing. |
| 4 | **Multiline** — numbered lines; Alt+Enter submits. | prompt_toolkit multiline Enter/newline and Meta+Enter or Escape-Enter submission [P2]; `TextAreaModel` [D2]. | Portable submission alternative; wrapping versus logical line numbers; scrolling, limits, paste, indentation, and editor escape behavior. |
| 5 | **Autocomplete** — `pn` with `pnpm`/`pnpx`; Tab completes. | Terminal completion [P2, P3]; suggestions [D3]. **Analogy:** editable combobox [W2]. | Candidate focus versus committed text; Tab ownership; cycling; accepting versus submitting; asynchronous suggestions and no-match state. |
| 6 | **Confirm** — Yes/No; Y/n; default yes. | Readline-style line acceptance is a useful substrate [P1]; keyboard-driven prompts [P3]. | Whether single letters submit immediately; Enter/default semantics; invalid input; explicit opt-in default for destructive operations. No default safety decision made here. |
| 7 | **Select** — active Starter row; arrows move, Enter selects. | InquirerPy select [P4]; `SelectListModel` [D2]; local trial [L2]. | Focus versus provisional selection, wrapping, disabled items, Home/End, type-ahead, empty lists, stable result identity. |
| 8 | **MultiSelect** — two selected; Space toggles. | InquirerPy multiselect [P4]; `MultiSelectModel` [D2]; local trial [L2]. | Focus independent of checked state; min/max count; select-all scope; filtered hidden selections; output order and Enter submission. |
| 9 | **SearchSelect** — `/ eu`; two of twelve matches. | InquirerPy fuzzy selection [P5]; text plus list models [D2, D3]. | Matching algorithm, editing/navigation ownership, no matches, selection preservation, async results, and whether exact typed values are allowed. |
| 10 | **Checkbox** — two independently checked/unchecked settings; Space toggles. | Terminal checkbox-list behavior [P4, D2]. **Analogy:** separate focus/selection [W1]. | Single boolean versus group; mixed state; grouping and submission; distinct active-row and checked indicators. |
| 11 | **Radio** — Stable/Canary; one choice only. | Single-choice terminal list [P4, D2]. **Analogy:** focus/selection distinction [W1]. | Immediate selection on movement versus explicit commit; optional no-selection state; whether distinct from Select in semantics rather than appearance. |
| 12 | **TreeSelect** — expanded packages, collapsed docs; Left/Right expand, Enter selects. | Keyboard/list substrate [D2, D4]. **Analogy:** composite navigation [W1]. | Expand versus select; branch selectability; hierarchy announcement; lazy loading, parent navigation, disabled nodes, and deep/narrow layout. No turnkey tree implementation verified. |
| 13 | **Toggle** — ON/off; Space switches, Enter accepts. | Keyboard editing/selection substrate [D2, D4]. | Boolean provisional state versus immediately applied setting; rollback on cancellation; explicit on/off words; distinction from Checkbox. |
| 14 | **Slider** — value 6, range 0–10, step 1; Left/Right adjust. | Key messages and custom view [D2, D4]. | Numeric direct-entry alternative; bounds, step, large changes, Home/End, numeric precision, and meaningful spoken value. Bar alone is insufficient. |
| 15 | **DateInput** — month focused; Tab segments, Up/Down adjusts. | Editor/key substrate [D3, D4]; no verified segmented terminal precedent in inspected sources. | Date format/locale, invalid intermediate dates, month rollover, calendar system, direct-entry fallback, segment navigation and submission. |
| 16 | **TimeInput** — hour focused; 24-hour format; Tab segments. | Editor/key substrate [D3, D4]. | Precision, seconds, 12/24-hour policy, overflow, timezone relation, direct entry, and segment/editing conflicts. |
| 17 | **PathInput** — `./dist/`; writable-directory feedback; Tab completion. | Terminal completion [P2, P3]; editor [D3]. | File versus directory expectations, relative base, quoting, home/environment expansion, permissions, races, symlinks, and Windows path forms. |
| 18 | **Keypress** — captured Ctrl+K; Escape cancels. | Keyboard messages [D4]; protocol constraints [T1]. | Supported observable keys, reserved cancel key, intercepted shortcuts, repeats, and whether acceptance is immediate or confirmed. Cannot promise arbitrary physical-key capture. |
| 19 | **Text** — normal text, hint, success, warning/error. | Custom rendered output [D1, D2]. | Semantic categories and transcript behavior; explicit labels without color; no unnecessary focus; wrapping and output-channel policy. |
| 20 | **Progress** — 64%, count, elapsed and ETA. | Custom rendering and message updates [D2]. | Determinate units, unknown totals, rate limiting, completion/failure summaries, reduced-motion output, and unvalidated announcements [T4]. |
| 21 | **Spinner** — static frame, task detail, Ctrl+C hint. | Asynchronous model updates/custom rendering [D1, D2]. | Animation cadence, plain-text alternative, cancellation ownership, terminal cleanup, and final persistent status. Static atlas frame proves no runtime animation. |
| 22 | **MultiSpinner** — done/running/failed/waiting tasks and counts. | Message-driven updates/custom view [D1, D2]. | Stable task ordering/IDs, failure details, concurrent updates, partial success, cancellation, and readable non-animated summaries. |
| 23 | **TagInput** — three tags; Enter adds, Backspace removes. | Editor substrate [D3]; completion precedent [P2]. | Enter-add versus finish conflict; delimiters, duplicates, quoted/pasted tags, focused-tag removal, undo and accidental deletion. |
| 24 | **MaskedInput** — partially filled license-key template. | Single-line editing [D3]. | Formatting is not password masking; literal characters, cursor mapping, deletion, partial input, paste normalization and allowed character policy need custom semantics. |
| 25 | **RegexInput** — pattern plus matches/group count. | Editor/validation substrate [D3]. | Regex dialect, literal notation, flags, invalid patterns, sample ownership, evaluation cost and cancellation; do not imply all pattern execution is bounded. |
| 26 | **URLInput** — HTTPS URL and parsed host feedback. | Text and validator separation [D3, P2]. | Accepted schemes, relative references, normalization, credentials, internationalized hosts, and whether optional network checks occur. Parsing is not reachability. |
| 27 | **EmailInput** — partial address with domain completion. | Completion/editor [P2, D3]. | Accepted syntax, internationalization, domain suggestion privacy, multiple addresses, and explicit separation of syntax from deliverability. |
| 28 | **ColorInput** — hex value, RGB conversion, swatch; named colors accepted. | Text editing/custom rendering [D2, D3]. | Supported formats/names, alpha and color space, conversion/rounding, truecolor fallback. The textual value must stand alone without a swatch. |
| 29 | **FilePicker** — directory context, selected `.dart` file, filter hint. | Navigable list plus editable path substrate [D2, D3]. | Directory opening versus file acceptance, filter semantics, hidden files, symlinks, permission errors, refresh, races, and Windows roots/network paths. |
| 30 | **DirectoryPicker** — parent and folders; Enter opens, Ctrl+Enter selects. | List/path composition [D2, D3]. | Ctrl+Enter portability [T1]; alternative “select current directory” action; root/parent behavior, permissions and symlink handling. |
| 31 | **PortInput** — 70000 invalid; 1–65535; default 8080. | Numeric text validation [D3, P2]. | Whether zero is allowed for automatic allocation is contextual; parse range versus bind availability; host/protocol context and race-prone availability checks. |
| 32 | **IPAddressInput** — IPv6 `::1`; IPv4/IPv6/CIDR hint. | Text/validation substrate [D3]. | Address versus network-prefix result, prefix bounds, scoped IPv6, normalization, hostnames, and preservation of user-entered representation. |
| 33 | **DurationInput** — `1h 30m`; normalized total. | Text/validation substrate [D3]. | Units, fractions, signs, repeated units, whitespace, precision/overflow, and whether months/years are excluded or calendar-relative. |
| 34 | **CronInput** — five fields, description and next run. | Text editor and asynchronous feedback substrate [D2, D3]. | Cron dialect/field count, timezone, DST gaps/overlaps, next-run calculation, reference clock and parse errors. Atlas text is not an executable scheduling specification. |
| 35 | **TimezoneSelect** — city/zone/offset search; New York and EDT offset. | Searchable choice precedent [P5]; editor/list models [D2, D3]. | Canonical zone ID versus fixed offset, aliases, database version, reference instant and DST. A displayed offset must not silently replace zone identity. |
| 36 | **RangeSlider** — min 20/max 80; Tab endpoint, Up/Down adjusts. | Key/custom-view substrate [D2, D4]. | Endpoint focus, crossing/clamping, minimum gap, precision, direct numeric alternative, bounds and spoken endpoint/value identity. |
| 37 | **SortableSelect** — ordered items; arrows focus, Ctrl+arrows reorder. | List/key substrate [D2, D4]. | Modified-arrow compatibility [T1]; explicit move mode/action alternative; announce new position; distinguish selected item from order; undo/cancel and stable IDs. |
| 38 | **KeyChordInput** — Ctrl+K then Ctrl+C; Escape clears, Enter binds. | Typed key messages [D4], constrained by protocol [T1]. | Sequence versus simultaneous chord terminology; timeout, reserved Enter/Escape/Ctrl+C, conflicts, repeat/release events, and terminal interception. “No conflict” requires an explicit conflict scope. |
| 39 | **CommandPalette** — query, fuzzy command candidates; Enter runs. | Fuzzy/search terminal precedent [P5]; editor/list composition [D2, D3]. **Analogy:** combobox candidate navigation [W2]. | Candidate versus execution, side-effect confirmation, disabled commands, query editing, result order, async availability, dismissal and focus restoration. |

## 6. Accessibility and broad compatibility

### 6.1 What is established

- Terminal protocols constrain which key distinctions an application can receive. [T1, T2]
- Windows native console modes must be managed and restored correctly. [T2, A1, A2]
- Terminal and screen-reader combinations have platform-specific accessibility behavior and settings. [T3, T4]
- Dart TUI documents event, model, and rendering facilities, but the inspected material does not establish a cross-platform accessibility guarantee. [D1–D7]

### 6.2 What is inference or recommendation

The following are research recommendations, not completed design decisions:

- Preserve full keyboard operation without requiring a mouse.
- Do not require color, Unicode symbols, animation, or a particular modifier chord to understand or complete a prompt.
- Evaluate a transcript-oriented mode with explicit labels, choices, state words, errors, and final answers.
- Avoid treating terminal focus events as control focus or screen-reader focus.
- Evaluate whether a visible terminal cursor improves reading-position behavior; do not assume a painted cursor has equivalent effects.
- Prefer stable, comprehensible updates over constant whole-screen churn when speech output is involved.
- Make errors and task completion persistent enough to review.
- Test with actual users of assistive technology before claiming screen-reader usability.

### 6.3 Unperformed validation matrix

A later validation plan should name exact versions rather than only operating systems.

| Dimension | Needed validation |
|---|---|
| Windows | Windows Terminal and any additional supported console host; exact input-mode/cursor restoration; Narrator and/or another explicitly supported screen reader. |
| macOS | Terminal.app and any additionally supported terminal; VoiceOver; modified keys, Option/Meta configuration, scrolling and redraw behavior. |
| Linux | Explicit terminal emulator(s), desktop/accessibility stack, and screen reader such as Orca; no Linux accessibility behavior was established here. |
| Terminal transport | Local terminal, SSH where supported, multiplexer where supported, and legacy versus extended keyboard protocols. |
| Output capabilities | Monochrome/no-color, ASCII, reduced animation, narrow dimensions, resize, and non-interactive streams. |
| Input | Real clipboard paste, bracketed/non-bracketed paste, Unicode graphemes, wide characters, control characters, repeat events, and intercepted shortcuts. |
| Lifecycle | Submit, cancel, interrupt, EOF, thrown errors, repeated sessions, asynchronous completion after exit, external-process handoff, and restoration. |
| Screen-reader tasks | Discover prompt/help, identify active item and selected state, hear validation errors, review list context, complete complex controls, cancel safely, and review final results. |

This matrix describes work to perform; it is not a claim that the listed combinations are supported.

## 7. Decisions and validation tasks for the map

No new human decisions were made by this research.

### Decision questions

1. **Supported compatibility envelope:** Which terminal hosts, transports, minimum protocol capabilities, and assistive-technology combinations are release targets?
2. **Operating modes:** Is a linear/transcript-oriented interaction mode required, and how is it selected? Do not assume automatic screen-reader detection.
3. **Shared interaction contract:** What do Enter, Escape, Ctrl+C, EOF, Tab, Home/End, and printable shortcuts mean across editing, selection, and nested controls?
4. **Focus and commit policy:** Which controls distinguish active candidate, provisional value, committed selection, and submitted answer?
5. **Validation policy:** When are errors shown, what blocks submission, and when are environment/network checks permitted?
6. **Complex-control boundaries:** Are filesystem browsing, schedule interpretation, shortcut conflict detection, and reorder interactions part of the initial scope, optional modules, or deferred?
7. **Dependency adoption:** Which exact Dart TUI revision is acceptable, and will the local restoration patch be retained until an equivalent upstream implementation passes regression tests?

### Suggested validation tasks

- **V1 — Pin and inspect backend:** Resolve release/archive/revision; verify relevant API signatures and raw-mode save/restore ordering; record hashes.
- **V2 — Restoration regression:** Retain exact original/final Windows flags and cursor checks across repeated sessions and all exit/error paths; add macOS/Linux lifecycle checks.
- **V3 — Input compatibility:** Test atlas-proposed modifier combinations and provide discoverable alternatives where indistinguishable or intercepted.
- **V4 — Editing correctness:** Test Unicode, graphemes, width, paste, multiline wrapping, masking, limits, and control-character handling.
- **V5 — Selection correctness:** Test focus/selection distinction, disabled items, filtering, stable identity/order, empty/no-match states, long lists, and reordering.
- **V6 — Accessibility feasibility:** Build minimal interaction probes for editing, selection, validation, and feedback; test real screen-reader task completion before committing to a full component design.
- **V7 — Rendering resilience:** Test resize/narrow terminals, scrollback, ASCII/monochrome, reduced animation, and asynchronous output.
- **V8 — Domain specifications:** Separately define parsing and semantics for dates/times, filesystem paths, addresses, durations, cron/timezones, regexes, and key sequences.

## Conclusion

Dart TUI remains a plausible implementation substrate, supported by a limited local prototype and documented editing, event, selection, rendering, and lifecycle facilities. That evidence does not establish accessible behavior for all 39 specimens or broad Windows/macOS/Linux compatibility.

The next step is to resolve the backend revision and restoration gate, define the shared interaction and accessibility validation contracts, and then specify component families. The atlas should remain traceable visual evidence—not be promoted directly into a public API or a claim of implemented behavior.