# Specify choice and hierarchical-navigation interactions

Type: grilling
Labels: wayfinder:grilling
Status: resolved
Blocked by: 04, 10
Assignee: primary-agent
Parent: [Trelis accessible prompt interaction specification](../map.md)

## Answer

Confirmed by the human after live discussion. This defines interaction contracts for all eleven named specimens; it does not implement them, merge their Dart APIs, execute commands or certify platform/accessibility support.

### Shared state and identity

- Choice changes remain local draft state until explicit submission. Navigation never submits or executes. Cancellation yields no accepted answer or application-side changes.
- Distinguish focused, selected, unavailable and locked states through readable text, not color alone.
- Disabled choices remain focusable, expose unavailable state/reasons and cannot be selected. This supersedes the archived skip-disabled prototype policy.
- Ordinary navigation stops at boundaries by default. If wrapping is offered it must be explicit/documented; do not silently cycle lists.
- Keep stable item identity and displayed item references throughout a prompt. Filtering, paging and reordering cannot recycle a reference for another identity. Report result/order position separately.
- Resolve answers through identity, not label text or current row index. Reject stale/removed references, newly unavailable selections and invalid defaults rather than silently substituting another choice.
- Identify configured defaults clearly. Do not conflate focus with a separately displayed selected/default state.
- Show meaningful empty, no-match, loading and all-unavailable states with recovery/help/cancellation actions. Never invent a successful choice.
- Preserve draft state on validation failure. Required constraints and selected/result counts must be reviewable.
- Long linear lists support explicit paged review with stable references and counts. Advertise applicable /next and /previous actions; page boundaries do not redefine item identity.
- Linear /help and /cancel follow the shared exact-command grammar; additional commands listed below must be advertised. Number/action stages are explicit, not hidden prefix parsing.

### Confirm

- Default visibly to No unless the application explicitly configures another default.
- In rich mode y/n shortcuts change draft Yes/No without submitting; Enter accepts the current displayed draft/default.
- Linear mode accepts documented Yes/No answer lines. A completed empty line accepts the displayed default. EOF, missing input and interruption never do.
- Do not silently infer a destructive-operation policy or execute application effects. The application owns the consequences of an accepted boolean.

### Checkbox and Toggle

- Each is one standalone boolean, initially false/off unless explicitly configured otherwise. Different presentation does not imply different side effects.
- Space toggles the rich draft; Enter submits it. Keep checked/unchecked or on/off state explicit.
- Linear mode supplies Yes/No equivalents and clearly displays the configured/default boolean.
- MultiSelect, not Checkbox, represents a group of independently chosen items. This semantic distinction does not require merging public APIs.

### Select and Radio

- Each returns one choice. Arrows navigate; Enter explicitly chooses the focused enabled item and submits it without requiring Space first.
- Focused unavailable items cannot be accepted; explain why and retain the prompt.
- A separately displayed default/selection must remain distinguishable from navigation focus. Enter's action on the focused item is explicit in instructions.
- Linear mode accepts a stable item number rather than ambiguous label text. Show the configured default when present; never silently replace an unavailable default.
- Radio shares Select's answer/submission semantics while retaining its visual presentation.

### MultiSelect

- Rich Space toggles a focused enabled item without submitting. Enter validates/submits the complete draft set.
- Linear entry toggles one displayed item number per line and reports its new checked/unchecked state. /selected reviews the full set including hidden items; /done attempts submission.
- Empty is a valid set by default, not cancellation. Caller-specified minimum/maximum constraints are shown.
- Enforce minimum count at submission. Reject additions or bulk updates exceeding maximum constraints as a unit, preserving prior state rather than partially applying.
- Filtering preserves selection by stable identity. Report total selected and hidden-selected counts and provide complete review before submission.
- Output selected identities in original canonical option order, independent of toggle history, filtering or scrolling. Explicit reordering belongs to SortableSelect.
- Bulk actions are Select visible and Clear visible; in linear mode advertise /select-visible and /clear-visible. Scope is enabled items in the entire current filtered result set, not just the displayed page. Hidden selections remain unchanged.
- Disabled items cannot be newly checked. Unavailable selected items cannot silently enter a submitted result; expose them through review/correction rather than substituting another item.
- An all-unavailable dataset is not a successful single choice. A genuinely valid empty MultiSelect set may still be submitted when no minimum prohibits it.

### SearchSelect

- Return one available choice, not arbitrary unmatched text. Autocomplete is the separate free-form assistance contract.
- Default matching is case-insensitive substring search over advertised searchable labels, preserving original option order. Other fields/matching/ranking policies must be explicit and described; matching must not rewrite answer identities.
- Query focus and result focus are distinct. Enter in the query moves to results without submitting; Up/Down can also enter results. Enter in results submits the focused enabled choice.
- Tab traverses query/results/actions. Typing to filter returns to query editing rather than becoming letter-jump selection.
- No-match remains editable and cannot submit free text.
- Linear flow is query entry followed by numbered results/actions. A valid enabled result number selects/submits; /search returns to query editing. Paging/help/cancellation are explicit.
- Keep query, focus, result count and availability understandable. Reject stale result references or asynchronous results from an obsolete query rather than accepting another item.

### CommandPalette

- Share SearchSelect's default substring matching, original ordering and explicit query/result focus.
- Optional fuzzy matching/ranking must be explicitly configured and described, with stable identity and predictable tie-breaking.
- Return the explicitly accepted command identity. Never execute it from navigation, preview, filtering or within the component itself.
- Raw unmatched query text is not a command to run. Availability and errors remain visible; application-owned execution and any consequential confirmation stay outside the palette.

### TreeSelect

- Return one explicitly selectable node; leaf-only selection is the default. Caller-declared selectable branches do not imply descendant selection.
- Expandability/traversal is distinct from selection permission. A selection-disabled branch can still be inspected/traversed where navigation is available; explain unavailable operations.
- Rich Up/Down traverses visible rows. Right expands a branch or enters its children. Left collapses a branch or goes to its parent.
- Enter on a selectable enabled node submits it. On a nonselectable branch it only expands or explains the available navigation action; it never pretends that branch was accepted.
- Expose full path/context, level and expanded/collapsed state without relying on indentation alone.
- Linear /open asks for a branch reference; /up visits the parent; /choose offers eligible current/visible nodes and explicitly submits the chosen node. Show current path, numbered children and state/reasons.
- Keep branch opening separate from selecting a node, including when a branch is selectable. Root/empty/error states must not trap the user or fabricate descendants.
- No implicit checkbox cascade, ancestor mixed-state behavior or hierarchical multiselect is included.

### SortableSelect

- Return a permutation of the whole supplied list of identities; no implicit membership changes.
- Distinguish stable item reference from changing position/order.
- Rich Space picks up a reorderable item; Up/Down moves it in draft order and reports the new position.
- Space or Enter while moving drops without submitting. Enter when idle submits the order.
- Escape during a move reverts that current move and returns to navigation; a later root Escape cancels the prompt. Prior completed draft moves remain until submission/cancellation.
- Locked anchors remain focusable with readable reasons and keep their positions. Items cannot cross anchors; reordering is limited to unlocked segments. Reject forbidden moves without partial rearrangement.
- Linear /move asks separately for item reference and destination position, validates anchor/boundary restrictions, and reports resulting order. /done submits the final permutation.
- No required Ctrl+arrow or other modified-key shortcut; any accelerator is supplementary and capability-specific.

### TimezoneSelect

- Follow SearchSelect's choice/query/result rules.
- Return a canonical zone identity from a declared IANA-zone dataset, not the current displayed UTC offset.
- Labels, cities and offsets are contextual search/display information. Extra searchable fields must be advertised.
- Identify the dataset version and reference instant behind offset previews; do not silently mix reference instants or replace zone identity with a fixed offset.
- Any timezone-data provider/API decision is separate from claiming that an atlas label is a complete scheduling implementation.

### Initial focus and result re-entry (readiness addendum)

Focus is navigation state, not selection. Initial single-choice focus is the configured default when present; otherwise the first enabled available choice; otherwise the first available choice. An unavailable default remains visibly focused for warning/review but cannot be submitted. Never silently substitute another answer when a configured default is unavailable.

For SearchSelect, CommandPalette and TimezoneSelect, entering/reopening results first focuses the still-valid configured/default or existing matching choice as appropriate, otherwise the first enabled result. Resume valid prior result focus when available; if it no longer exists/becomes unavailable, report the invalidity rather than choosing a replacement silently. Query focus/result focus and Enter acceptance rules remain unchanged.

For all-unavailable results, focus can remain on the first available item for review but cannot be accepted as an enabled choice. Paging/filtering keeps identity/reference rules and never invents a focus default that submits without clear review.

### Verification and scope

- Test identities/references independently of labels, filtering, pagination and sort position.
- Include boundary navigation, disabled reasons, invalid/stale defaults, no results/all-unavailable, selected-but-hidden review, count constraints, partial bulk failures, tree branch selection and locked-anchor moves.
- Test query/result focus and Enter semantics separately from Autocomplete; palette navigation must never execute anything.
- Verify genuine keyboard/screen-reader task completion in exact Windows/macOS/Linux environments under [Choose the accessibility verification matrix and evidence gates](11-verification-matrix.md).
- All state/output rules follow the shared contract's stream, lifecycle, literal-command and support-evidence boundaries. No platform or assistive-technology combination is certified here.

## Question

What are the accessible interaction contracts for Confirm, Select, MultiSelect, SearchSelect, Checkbox, Radio, TreeSelect, Toggle, TimezoneSelect, SortableSelect and CommandPalette? Define focus versus selection, navigation/search/filtering, disabled choices, reordering where relevant, commitment/cancellation, announcements and fallback behavior.
