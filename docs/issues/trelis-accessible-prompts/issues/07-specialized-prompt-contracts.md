# Specify specialized value and key-capture interactions

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04, 10, 15
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. This resolves eight specialized-input contracts and their shared principles. The full locale-calendar DateInput decision was resolved separately after this ticket; no implementation, backend adoption or verified platform/accessibility support is claimed.

### Shared specialized-input rules

- Keep draft editing/navigation separate from accepted answers. Provide equivalent rich/linear task outcomes, not necessarily identical gestures.
- Expose value, units, constraints, active segment/endpoint, errors and available actions as text rather than color/position alone.
- Direct entry, correction and explicit submission must be available without a required mouse or enhanced modifier-key protocol.
- Respect the shared editor, command/literal, stream, capability, cancellation, lifecycle and support-evidence contracts. Configured defaults require actual capable editing; do not silently substitute pending-default acceptance.
- Preserve invalid drafts for correction; do not silently round, swap, reinterpret or invent a successful value.
- This decision does not override [Specify locale-calendar DateInput interactions](17-locale-calendar-date-contract.md), which holds the human's established slash/system-locale/non-Gregorian/native-digit requirements.

### Slider

- Show configured bounds, step, units and current value, plus a precise numeric-entry path.
- Step constrains both typing and arrow adjustment: valid values align to the declared step from the minimum and lie within bounds.
- Reject off-grid/out-of-range typed values with retained text and actionable constraints; no silent rounding.
- Rich slider focus uses arrows for adjustment; numeric-editor focus uses arrows for ordinary text editing, not slider movement. Provide visible Edit/Submit actions.
- Linear entry accepts a constrained numeric value with the same validation and explicit submission rules.
- Display-boundary behavior must not silently wrap. Precision and bounds must be representable consistently; backend arithmetic is not selected here.

### RangeSlider

- Apply Slider's step/range/precision rules to both values.
- Keep Lower and Upper endpoint identities stable and announce the active endpoint/value.
- Tab reaches endpoints and visible editing/submission actions. Do not require a modified key to choose or precisely edit an endpoint.
- Endpoints never swap roles. Arrow adjustment stops at the other endpoint or configured minimum-gap boundary.
- Equal endpoints are allowed unless an explicit minimum gap prohibits them. Typed inverted/invalid pairs remain editable with errors.
- Linear mode edits both endpoint values and then offers review/submission of the pair; editing one endpoint cannot silently submit an incomplete range.
- No silent clipping or rounding of typed values to fit another endpoint.

### TimeInput

- Represent time of day only. Do not infer a date, timezone or UTC instant.
- Default format: 24-hour HH:mm. Optional seconds and 12-hour format are explicit configuration with prominent labels, including required period indication for 12-hour input.
- Tab moves through labeled segments; Up/Down adjusts the selected segment within its limits. Direct formatted entry remains available.
- Stop at segment boundaries. No wrap, carry into another segment or implied midnight/date rollover.
- Incomplete and invalid states are editable, not automatically normalized into a valid time.
- Do not silently roll 24:00, invalid minute/second values or an invalid period into another value. Explain accepted format/ranges and retain text.
- Rich and linear modes interpret the same declared precision/format rather than guessing missing context.

### PathInput

- Default policy requires an existing target. A prospective/nonexistent path is permitted only through explicit caller configuration; state existence/type requirements to the person entering it.
- Capture and display a stable resolution base at prompt start: an explicit caller base or current working directory.
- Return an absolute path resolved against that base under native path rules; never change process working directory as navigation state changes.
- Disclose the resolved candidate before acceptance. Do not automatically replace it with a symlink target, or silently collapse path syntax in ways that change symlink-sensitive .. semantics.
- Native literal path syntax is the default: no implicit tilde/environment-variable/glob expansion, shell-quote stripping or shell execution.
- Any offered convenience expansion must be explicit, documented and previewed. Literal spaces, dollar signs, quotes or tilde characters cannot acquire hidden shell meaning.
- Apply shared command-aware quoting where relevant, including slash-command collisions and leading-backslash Windows paths. Preserve decoded answer semantics; do not treat command quoting as generic shell escaping.
- Existence/type/permission errors retain the candidate and context. A returned path does not guarantee that a later operation succeeds.

### FilePicker and DirectoryPicker

- FilePicker selects an existing file; DirectoryPicker selects an existing directory.
- Browse/read metadata only: no creation, deletion, rename, overwrite or opening selected content on the application's behalf. Save-as and new-directory mutation flows are not included.
- Distinguish Open from Choose when a directory can have both roles. Never require Ctrl+Enter to select the current directory.
- Provide direct path entry, parent navigation, refresh and an explicit hidden-item toggle. Keep the current path, visibility policy, entry type and selectable/unavailable state reviewable.
- Rich navigation/visible actions and linear named/numbered actions must provide the same browsing/selection outcomes without relying on indentation or color.
- Retain stable entry references while displayed; stale references cannot silently target replacements. Refresh/access failures preserve useful browsing context.
- Symlinked-directory traversal is explicit opt-in. Label links and explain unavailable traversal otherwise.
- Enabled link traversal requires cycle/error handling. Validate platform-specific directory-link/reparse behavior rather than assuming POSIX link detection covers Windows.
- Recheck existence and required type at acceptance, but do not promise race-free later file access or atomic security checks.
- A starting/base directory is not implicitly a security sandbox. No confinement guarantee is introduced by this contract.

### Logical key model

- Describe logical terminal keys and observable modifiers, not physical positions/scancodes or global hotkey registration.
- Do not infer a US physical key from committed text or assume arbitrary modifier/key-up/simultaneous-key-state reporting.
- Identify unsupported or ambiguous distinctions. A legacy collision is not evidence that a richer physical combination was uniquely observed.
- A key gesture is one logical key with its reported modifiers. A KeyChordInput sequence is ordered gestures, each possibly modified—not arbitrary simultaneous nonmodifier tracking.

### Keypress and KeyChordInput flow

- Explicitly arm Capture next gesture, then return to review/actions after one candidate. Capture does not immediately submit.
- Keypress accepts exactly one gesture. KeyChordInput accepts one or more ordered gestures with explicit capture/add, remove-last, clear and submit actions.
- Do not infer sequence completion from a timing gap. Ignore repeat events as extra gestures from one arming.
- Provide a documented textual logical-key vocabulary and explicit declaration/review when reliable capture is unavailable.
- Preserve observed/declared provenance per gesture, including mixed sequences. Do not label an entire mixed sequence observed or convert declaration into verification.
- Callers may require observation; reject declared entries under that requirement instead of silently substituting them.
- A declaration does not prove future terminal delivery, application usability or lack of binding conflicts.
- Do not claim no conflicts without an explicitly scoped check; no OS/global binding registration is performed.

### Reserved keys and safe exit

- Ctrl+C always interrupts the whole prompt. It is not captured live as a binding.
- Escape leaves armed capture before root cancellation, preserving the shared layered-exit guarantee; it is not captured live as a binding.
- Enter/Tab can become observed candidate keys only while capture is explicitly armed. Outside that state they remain advertised actions/navigation.
- Textual Escape/Ctrl+C declarations can be reviewed/submitted as declared with prominent reserved-here/unverified warnings.
- Cancellation remains discoverable; capturing a candidate does not consume every route out or trap the user.
- Literal descriptor data must not be replayed as live terminal key input.

### Date follow-up and verification

- [Investigate system date conventions across desktop platforms](15-system-date-conventions.md) is a completed documentation investigation, not OS behavior verified by tests.
- [Investigate calendar-aware slash date entry and date-only results](16-locale-calendar-feasibility.md) informs the still-required [Specify locale-calendar DateInput interactions](17-locale-calendar-date-contract.md).
- [Choose the accessibility verification matrix and evidence gates](11-verification-matrix.md) must cover both rich/linear numeric entry, focus-versus-adjustment, range boundaries, time formats, native path/drive/UNC and quoting behavior, symlink/junction/reparse/cycle/access failures, refresh races, actual gesture observation/declaration, repeats, reserved keys and terminal restoration.
- Include real keyboard/screen-reader task completion. Synthetic decoded events and documentation alone do not certify any Windows/macOS/Linux combination.

## Question

What shared specialized-input principles and detailed interaction contracts apply to Slider, RangeSlider, TimeInput, PathInput, FilePicker, DirectoryPicker, Keypress and KeyChordInput? Decide precise entry versus visual navigation, multiple-value focus where relevant, safe key capture/collisions, validation, discoverability, cancellation and rich/linear equivalence. DateInput's full slash/system-locale/non-Gregorian contract moved to [Specify locale-calendar DateInput interactions](17-locale-calendar-date-contract.md) after research exposed separate calendar/era/leap-month decisions; it remains required before readiness.
