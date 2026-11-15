# Specify the internal typed presentation and layout vocabulary
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou
Blocked by: 02

## Question

Under the approved [declarative presentation contract](02-declarative-presentation-boundary.md), what concrete internal typed presentation variants, shared subparts, layout primitives and renderer output contracts are required? Specify common semantic slots, component-family coverage/reuse, stage/action/help representation, incomplete editable content, stable identity and logical caret anchors, semantic spans, rich composition and meaningful linear output events. Define how required roles survive instruction filtering and composition, and how safe projections prevent secret/credential leakage. Define the narrow interface between layout and renderer without exposing controllers, callbacks that perform behavior, or terminal writes. Account for text, choices/tree/order, segmented/range, search/browser/review and feedback families. Decide dedicated anchor node versus span metadata and event identity/update semantics rather than leaving them implicit. This is an internal design specification, not a public UI framework or implementation. Consult Dart and codebase-design.

## Answer

Approved by bvlou through live decision rounds and explicit final confirmation. Dedicated editable-region nodes, automatic insertion of omitted protected content, and explicit ordered events plus current-view state were selected. These are internal design requirements, not implemented Dart declarations or a public authoring framework. Internal identifiers below are schema labels; spelling may follow repository conventions without changing the distinctions.

### Small presentation interface

Behavior produces an immutable presentation update containing:

- Session identity and monotonically ordered update revision.
- Current presentation view: stage, typed content, safe context, current actions and help, logical active control, semantic notices and lifecycle state.
- Zero or more ordered, individually identified presentation events for sequential history. A view revision is not itself a transcript event.

Structure composition is a pure transformation from display-safe view/event content plus instruction policy and layout context to declarative layout. Layout context contains dimensions, interaction mode and rendering capabilities, not terminal handles or mutable component state. Palette resolution remains separate. No generic value T, validator, controller, key handler, async future or behavior-performing callback crosses this interface.

Use closed typed alternatives and immutable typed subparts, not dynamic maps or one universal object with nullable fields for every possible component. Reuse common semantic subparts; do not introduce one copy of each body type per structure.

### Common semantic records

| Record | Required meaning |
|---|---|
| Session/control/content identity | Opaque, session-scoped identity independent of display label, list position or sensitive value |
| Stage | Current workflow stage and active control; enough to distinguish entry, query/results, actions, help and review |
| Display text | Approved display content and semantic text runs, with no embedded terminal command interpretation |
| Action description | Semantic action identity, target control, current availability, label and truthful current binding/command description; no executable handler |
| Context cue | Active format/calendar/convention, location or other interpretation-critical context |
| Notice | Stable content identity, semantic kind, approved text, relevant target/stage and required/optional presentation status |
| Help model | Current-stage actions first, wider workflow/format sections and supplementary help; safe route/dismissal descriptions reflect actual capabilities |
| Lifecycle/status | Running, intermediate state or explicit reported outcome, never inferred from a visual percentage |

Current-view persistent content identity and per-occurrence event identity are separate. The same warning may remain in a rich view across revisions; a fresh validation occurrence can have a new event identity even when its text matches an earlier error.

Instruction visibility filters optional instruction content only. Presence requirements for labels, body/state, help access, essential cues, applicable warnings, validation and required review/actions remain explicit. Conditional requirements apply only when content is relevant to the active stage/event; do not manufacture empty warnings or actions to fill slots.

### Typed body vocabulary and coverage

| Body family | Semantic contents and reuse |
|---|---|
| Text entry | Field identity, approved displayed draft, logical grapheme caret and edit context. TextInput and numeric/network/email/colour/duration wrappers reuse it with domain cues/help and safe preview content. |
| Hidden or masked entry | Separate alternatives: hidden presentation has no raw text, secret length or logical secret offset; masking exposes only approved mask presentation and mapped caret under explicit length disclosure. Used by Password and other hidden-draft paths such as URLInput. |
| Boolean | Current/default boolean state and kind-specific presentation facts; actions retain Confirm/Checkbox/Toggle semantics. |
| Choices | Stable/source or response-local display references, current page, focus, selected/checked state, default, unavailable state/reason. Do not collapse focus and selection. Selection values T remain in behavior. |
| Tree/order extensions | Choice subparts plus tree depth, expansion/selectability or locked anchor, pickup/movement state. Preserve original references and navigation rules. |
| Segments/ranges | Ordered editable subfields and their incomplete drafts, active control, field-local caret, bounds and edit/review actions. Date/Time/MaskedInput and sliders reuse the relevant parts without losing their different parsing/adjustment semantics. |
| Tags | Accepted tag items, current draft tag and focused/editing tag identity; addition and final completion remain distinct actions. |
| Query/results | Query editor plus distinct idle/loading/failure/ready states, result identities and focused candidate, open/dismissed state and stage actions. Ready with no entries is distinct from failure or loading. |
| Browser/review | Safe location/context, entries, interpretation/preview and stage-specific open/choose/edit/confirm actions. Reuse choice and action subparts rather than implement a separate layout engine. |
| Feedback | Reported count/total, phase, activity and explicit outcomes, with unknown/indeterminate state represented deliberately. Timers, cadence, start/update/finish/dispose remain behavior-owned. Text is semantic informational content rather than an interactive editor. |
| Composite | Typed composition of the above and required action/context subparts for workflows such as Cron preview or query plus results. Not an untyped arbitrary object escape hatch. |

Bodies are not pre-rendered opaque rectangles: structures can compose their typed subparts using shared templates. Conversely, structures may not invent new navigation/action meanings while rearranging them.

### Declarative layout vocabulary

Use a bounded composable vocabulary:

- Column and row composition with explicit order and spacing.
- Padding, gaps, rules, frames and rails.
- Styled text runs carrying semantic roles rather than hard-coded palette values or escape strings.
- Semantic slots referencing identified content/subparts.
- Dedicated editable-region nodes carrying the approved display variant, control identity and logical caret anchor.
- Shared typed item/field templates for repeated choice rows, tree/order items and segments; no independent theme-specific editor loops.

Help can compose another view using the same vocabulary. No general-purpose retained widget framework, arbitrary absolute-position API or public custom-layout interface is required. Width/viewport choices and glyph fallback policies are supplied by the per-structure contract, not silently fixed here.

An editable region is the owner of its logical caret anchor. Ordinary styled spans do not carry competing caret metadata. Preserve a single active control/caret in the active view, or explicitly no visible caret when appropriate. Renderer mapping must account for prefixes, frame placement, wrapping/clipping and displayed substitutions. A hidden region can anchor the physical input location without disclosing its secret's actual caret/length. A decorative atlas cursor glyph does not satisfy the editing-cursor requirement.

### Protected-content repair

bvlou selected automatic insertion, not rejection of a theme declaration when required content is omitted.

The shared compositor tracks which identified protected content the composed layout actually places. It inserts missing relevant content into a deterministic shared safety area adjacent to the body and before optional hints/help. Required body/context, warnings, validation and required action descriptions remain available, and the help route cannot be lost through an instruction override. Already-placed protected content is not reinserted merely because it shares a semantic role with another item.

Repair does not recreate the verbose optional introduction, change controls, expose hidden drafts or replace a component's formatting/validation policy. It operates on safe typed content, not the original component object. Theme declaration/coverage tests must still report omitted protected slots so repair does not make faulty declarations look correct. This repair policy is distinct from normal narrow-terminal or capability fallback.

For a linear event, repair considers only that event's relevant required content. It must not append all persistent warnings or a whole current-view snapshot on every event. Their first relevant stage entry and later material occurrences remain explicit presentation events.

### Explicit linear events and delivery

Minimum event categories are stage/view entry, meaningful displayed-state change (including text, caret, choice focus/selection where sequential presentation needs them), validation/interaction notice, user-requested help, review/interpretation presentation, feedback update/phase/outcome and prompt completion/cancellation/interruption/input-end as applicable to existing output contracts.

Each event contains session identity, monotonic occurrence identity/order, originating stage/control where relevant and approved typed content. Identity is not derived from message text or raw answer values. Rerendering the same event for the same sink/session does not append it again; a new user help request or repeated validation failure is a new occurrence even if the displayed text is identical. A resize/repaint or no-op key does not by itself create an event. Preserve meaningful caret-only movement.

Behavior controls which events are emitted and their order. Keep existing callback contracts and feedback milestone/time gating: do not repurpose current onChanged invocations as reliable text-change events, and do not put progress throttling in a theme. Renderer delivery must not replay history merely because the current view changed. This is in-session output identity/deduplication, not an exactly-once persistence guarantee across crashes or partial stream failures.

Rich rendering uses the current view. Linear presentation themes each sequential event into a reviewable block; where current backend capabilities support an editable active line, that active region remains distinct from committed transcript history. A renderer may not infer submission/completion or missing help occurrences by diffing snapshots alone.

### Async and choice identity

Behavior gates obsolete/closed-session callbacks before projection. SearchSelect retains source-based stable identities/references and clears/invalidates acceptance as required when query/focus/results change. Autocomplete candidates are response-local rather than universally stable choices: a request generation plus local candidate identity distinguishes them. Do not reinterpret their numeric positions as stable source identities.

Represent loading, empty success, generic failure, dismissed candidates, active candidate and accepted-candidate-versus-text-submission distinctions. Preserve actual retry/query rules; layout must not add a retry action just because a generic failure template has space for one. No raw exceptions or pending futures enter the presentation model.

### Secrecy and text safety

Projection applies approved display policy before layout. A Password secret, accepted secret, validator diagnostic or exception cannot be formatted by a structure through object stringification. Hidden fields do not expose raw content or length/caret metadata; masked display is a deliberate disclosed alternative. Stage/action content never carries retained secret drafts.

Only explicitly approved safe display summaries enter completion/interpretation events; do not automatically stringify Accepted<T> or arbitrary result values. URLInput currently hides drafts and rejects user-information authority, but can explicitly display the accepted URL interpretation; do not claim that all query/path/fragment content is currently redacted. Preserve component-specific approved output policy rather than inventing blanket automatic result echoes.

Treat user/application labels, notices and supplementary help as display text, not terminal commands. Shared safe display encoding must prevent control/bidi content from bypassing layout or terminal ownership while leaving underlying answer data unchanged. Editor-to-display caret mapping must account for encoded display content; do not assume every grapheme occupies one terminal cell. Exact physical width policy belongs to structure/renderer design.

### Renderer-facing contract

Composition returns a rich layout tree with stable region identities and an explicit logical caret anchor/no-caret state, or a sequential event layout with its occurrence identity and safe typed content. The renderer measures and places it, resolves semantic colour roles, maps the caret and emits supported output operations. Terminal/session acquisition and restoration remain with the backend. None of these results contains behavioral callbacks, raw ANSI from themes or mutable controller references.

### Evidence and next step

Source checks: lib/src/text_input.dart (_edit no-op/caret/callback behavior, Password display policy), lib/src/search_select.dart (source identities and generation gating), lib/src/autocomplete.dart (response-local candidates and dismissal/acceptance), lib/src/feedback.dart (cadence/lifecycle and safe text handling), lib/src/url_email_input.dart (hidden drafts and explicit accepted interpretation).

This resolves the representation question without implementing types. [Specify rich and linear presentations for the existing structures](04-rich-and-linear-structure-contracts.md) is now unblocked and must use this vocabulary, including safety-area placement, caret-aware width behavior and event-specific linear composition. No additional decision ticket surfaced.
