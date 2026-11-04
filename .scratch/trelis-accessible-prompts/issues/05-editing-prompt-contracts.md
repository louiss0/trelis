# Specify text and structured-input interactions

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04, 10, 12
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion, with the TagInput spelling-preservation proposal superseded by the kebab/snake policy below. This resolves shared editing rules for the originally covered text-based specimens (current scope subsequently excludes RegexInput; see the map's Out of scope section) and detailed contracts for TextInput, Password, Multiline, Autocomplete and TagInput. It does not implement or verify any component.

### Shared editing and interpretation

- Preserve entered text by default: no universal trimming, case-folding or Unicode normalization. Component-specific transformations must be explicit. The Multiline newline and TagInput normalization policies below are such exceptions.
- Distinguish editable representation, decoded answer and interpreted domain value. Apply the resolved command/literal grammar only at its declared boundary, before component parsing.
- Move/delete by extended grapheme cluster; user-facing character limits count graphemes. Byte/protocol/resource limits are separate documented constraints. Grapheme count is not terminal display width.
- Baseline editor actions: Left/Right by grapheme, Backspace/Delete adjacent graphemes, and Home/End to line boundaries where delivered. Multiline adds vertical movement and visible actions. Provide discoverable alternatives if a key is unavailable.
- Word movement, modified selection and clipboard accelerators are optional, capability-specific additions, never the sole essential path. Do not assume GUI Ctrl/Command bindings arrive through a terminal.
- Reject oversized insertions/paste as a unit and retain the prior valid content rather than silently truncating. If native editing already captured an oversized candidate, retain it for correction and block submission. Explain limits without replaying secrets. This is not permission for unbounded allocation; separately declared resource limits still apply.
- Preserve invalid input/drafts for correction and provide the shared persistent textual validation feedback. Identified paste is data and requires explicit submission; do not replay pasted control/newline sequences as actions.
- Local parsing/constraints are the default. External/network/environment checks require explicit caller opt-in, visible pending/error state and bounded/cancellable behavior. Syntax does not prove reachability, deliverability or availability.
- State required/optional status and relevant constraints. Optional empty input is an empty answer, not cancellation or default restoration.

### Initial values and mode capability

- A configured default is the actual initial editable value, not a placeholder. It must be editable and erasable. Erasing means empty subject to validation; do not restore the default implicitly.
- Require a capable editor in either selected mode. The human rejected showing a pending default accepted by /submit as a substitute. Preflight actual prompt/editor/stream requirements; declare an incapable interaction unavailable rather than silently dropping the default or changing semantics.
- No implicit default acceptance on EOF or missing interaction.
- In command-aware linear editors, encode colliding initial values reversibly through the shared quoting grammar, explaining that quoting is entry syntax. For example, answer /cancel appears as \/cancel in that editor; encode leading backslashes likewise.
- Rich literal editors do not add command-quoting syntax. Hidden secret editors are always literal.
- Validate and count answer limits on decoded values, not the extra escape syntax. After correction or reopening an editor, preserve literal values through the same explicit representation rules.
- [Investigate editable defaults in linear interaction](12-editable-default-feasibility.md) identifies candidate mechanisms and limitations, not an adopted backend or verified accessibility. Exact source, prefill, stream, EOF, provenance and screen-reader probes remain part of verification.

### TextInput

- Single-line editing with the shared actions, constraints and preservation rules.
- Enter attempts validation/submission of the current value. Linear command-aware entry exposes /help and /cancel and the documented quoting rules.
- A required empty value fails with correction guidance. An optional empty value is submitted as empty.
- Retain input on validation failure. Neither cancellation, interruption nor EOF accepts it.
- Newline-containing paste is subject to the single-line constraint; it cannot silently submit several answers or be truncated without explanation.

### Password

- No visible echo by default. Masking is explicit opt-in with length-disclosure implications documented. Do not display the raw value or secret length in prompts, help, errors or summaries.
- Allow secret prefill only as explicit caller opt-in and only with a capable editor. It is subject to dedicated disclosure and screen-reader verification, not ordinary default-preview behavior.
- Hidden editing bypasses command recognition, quoting and implicit normalization entirely.
- In both modes, Enter ends hidden editing and opens a separate visible action stage: Submit, Edit, Clear/re-enter, Help or Cancel. Never preview the value or its length at that stage.
- Submit validates the secret; failure retains it for correction without replaying it. Edit reopens the hidden current value; Clear starts empty. Neither empty input nor EOF means keep/accept an existing secret.
- Do not retain secret-bearing persistent history or diagnostic output. Do not advertise echo safety based only on terminal echo flags; assistive-technology typing behavior is a separate test requirement.
- The visible action stage must be clearly distinguished from hidden value entry; action/validation messages cannot expose the secret.

### Autocomplete

**Meaning:** suggestions assist entry, not an enforced allowed-value set. Independently valid unmatched text is accepted. Do not silently convert it to the nearest suggestion.

**Rich mode:**
- Merely showing suggestions does not activate a candidate or intercept Enter. Explicit navigation activates a candidate.
- Tab accepts the active candidate, or the first offered candidate, into editable text.
- Enter on an active unaccepted candidate accepts it without submitting. Enter when no candidate needs acceptance submits current text.
- Keep accepted-versus-unaccepted state clear; do not immediately reactivate a candidate merely to consume another Enter.
- Escape dismisses suggestions while retaining text before root cancellation. Query editing stays text entry, not printable selection shortcuts.

**Linear mode:**
- Enter a query, show numbered suggestions, then expose explicit actions.
- A candidate number accepts its text into the pending answer without submitting.
- /submit validates/submits pending text; /edit reopens it in the capable editor; /help and /cancel remain available. Advertise these commands and applicable literal-entry rules.
- No-match still permits independently valid free text through /submit. Revision returns to the query/suggestion flow.
- The pending-answer stage is an explicit Autocomplete interaction, not a fallback substitute for missing editable-default capability.

**Both modes:** distinguish query, candidate and committed editable text. Report meaningful counts/no-match/loading/error states without excessive repeated output. Stale async results must not replace newer results or silently commit a candidate.

### Multiline

- Rich Enter inserts a newline. Tab reaches visible actions including Finish; Enter activates the focused action. Provide explicit literal-tab insertion or paste rather than requiring a modified-Enter shortcut for completion.
- Linear entry accumulates logical lines; blank lines are data, not finish commands.
- Advertise /list for review, /edit for correction, /insert for insertion, /remove for deletion and /done to attempt submission, alongside /help and /cancel.
- Command tokens are exact whole lines. Select line numbers in subsequent explicit steps, not through undeclared prefix parsing. Editing an existing line uses its actual value prefilled in a capable editor and appropriate literal encoding.
- Removing a line requires confirmation. Keep review/correction paths available; linear operation is not append-only.
- Return logical lines joined with LF. Normalize pasted CRLF and CR to LF as an explicit component policy. Preserve blank and intentional final blank lines; preserve other text.
- /done is control input, not an additional content line. Quote literal command lines using the shared grammar; identified pasted command-looking content remains literal.
- Failed final validation retains the buffer for correction. Escape/Ctrl+C and EOF follow the shared contract; EOF never implicitly finishes.

### TagInput

**Normalization:**
- Exactly two policies: kebab case (default) or snake case. The application configures the style before prompting, and the prompt explains it. No raw/preserve option, arbitrary normalization callback or mid-session style switch.
- Use the same word-aware boundaries for both styles: whitespace, underscore/hyphen separators and camel/acronym boundaries. Lowercase words, collapse separator runs and remove edge separators.
- Preserve Unicode letters, digits and their combining marks without ASCII transliteration. Reject unsupported punctuation with actionable feedback instead of silently deleting it.
- Examples: My NewTag → my-new-tag / my_new_tag; HTTPServer → http-server / http_server; Déjà Vu → déjà-vu / déjà_vu.
- An empty normalized result is invalid. Apply validation, answer-length constraints and duplicate comparison to the canonical value.
- Reject exact canonical duplicates and preserve the draft for correction; HelloWorld and hello world therefore collide. Retain insertion order.
- Rich mode previews canonical spelling without rewriting the draft while typing. Linear mode reports the normalized addition and offers edit/remove. No extra normalization-confirmation step is required.

**Actions:**
- Enter adds a nonempty valid draft. Empty Enter does not finish; provide Finish guidance.
- A separate rich Finish action or linear /done validates/submits the collection.
- If a nonempty unadded draft remains, require adding or explicitly discarding it before finishing; never silently lose it.
- Rich empty-draft Backspace focuses the last tag only. Delete or an explicit Remove action removes the focused tag; repeated Backspace is not automatic removal.
- Linear /list, /edit and /remove identify tags explicitly and /done finishes. Use subsequent explicit item selection, not ambiguous raw-text deletion.
- Editing replaces the same ordered position after normalization/validation; rejection preserves the draft and existing collection. Removal preserves the order of remaining tags.
- Paste is one draft tag, not implicitly split on comma/newline. Reject disallowed single-tag characters without truncation. Any future bulk-add is a separately explicit interaction with its own preview/quoting contract.

### Required follow-ups and verification

- [Specify numeric, network and color input contracts](13-numeric-network-color-contracts.md) holds NumberInput, PortInput, IPAddressInput, URLInput, EmailInput and ColorInput format/interaction decisions.
- [Specify mask, duration and cron input contracts](14-mask-pattern-duration-cron-contracts.md) holds MaskedInput, DurationInput and CronInput decisions. RegexInput was subsequently removed from scope.
- Those tickets are required before readiness; this resolution does not finalize their value dialects.
- [Choose the accessibility verification matrix and evidence gates](11-verification-matrix.md) must include actual initial-value editing, quoting collisions, graphemes/width, oversized and framed/unframed paste, newline preservation, secret modes/prefill, suggestion races, correction, cancellation, repeated sessions and screen-reader task completion.
- Tests must include both kebab/snake canonical collisions and Unicode tag examples. No platform, editor backend or screen-reader support is certified here.

## Question

What shared editing rules apply to TextInput, Password, NumberInput, Multiline, Autocomplete, TagInput, MaskedInput, URLInput, EmailInput, ColorInput, PortInput, IPAddressInput, DurationInput and CronInput, and what are the detailed interaction contracts for TextInput, Password, Multiline, Autocomplete and TagInput? Define user actions, editing/selection/paste, suggestions, validation, feedback, submission/cancellation and mode equivalence. As discussion exposed separate format decisions, the remaining component-specific contracts moved to [Specify numeric, network and color input contracts](13-numeric-network-color-contracts.md) and [Specify mask, duration and cron input contracts](14-mask-pattern-duration-cron-contracts.md); both remain required before readiness.
