# Define the declarative component presentation boundary
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou

## Question

What state, semantic output roles and action descriptions should components expose to declarative structural presentations, and what remains owned by component behavior and the terminal/session backend? Define enough of the representation and rendering responsibilities to support all existing structures without copying behavior per theme, leaking secrets, or losing state/validation/help semantics. Distinguish structure layout from palette and interaction behavior. Consult codebase-design and Dart.

## Answer

Approved by bvlou through live discussion and explicit confirmation of the ownership split. Internal declarative definitions with composable layouts and typed content were chosen over a public custom-structure framework and fixed templates with layout flags.

### Scope and interface

The public structural-theme classes expose static component factories. They configure shared components; they do not themselves consume input or render a live session. Consumers choose existing structural themes, independent colour-theme objects and supported overrides. Structure authoring stays internal for this effort; a public extensibility framework is deferred.

The internal presentation seam is immutable, display-safe component state, not raw strings, mutable controllers or a theme-specific input loop. A small composable layout vocabulary arranges typed component content and semantic slots. Rich and linear interaction share component task semantics but have intentional, separate structural declarations.

### Ownership

| Module | Owns | Must not own |
|---|---|---|
| Component behavior | Drafts, validation, parsing, key/action meaning, selection and navigation, stage transitions, command/literal distinctions, async request lifecycle, help availability/content, results and feedback lifecycle | Theme borders, glyphs, colours, physical cursor positioning |
| Presentation projection | Immutable display-ready stage, semantic content/roles, typed body, available action descriptions/bindings, help content, logical focus and caret; safe display policy applied before layout | Raw secrets, mutable editor/controller references, validators or input handlers |
| Structural layout | Composition of framing and body, rows/columns, spacing, rails/borders, glyphs, semantic style roles, per-component instruction defaults; separate rich and linear declarations | Reading keys, changing drafts or action meanings, accepting answers, validation, terminal writes, async work or timers |
| Terminal renderer/session | Measurement, clipping and placement, logical-to-physical caret mapping, colour-role resolution, terminal output, supported rich updates or sequential transcript emission, terminal acquisition/restoration | Deciding acceptance, navigation semantics, validation, task completion or feedback success |

Instruction policy is resolved using theme defaults and application overrides against the component-help contract. The component provides accurate current actions and guidance; the structure controls permitted presentation, not the truth of those actions. Required warnings, state, format cues, validation and review actions cannot be mistaken for hideable instruction copy.

### Minimum semantic state

These are required concepts, not final Dart type names or a giant universal object with nullable fields:

- Common content: prompt identity/label, current interaction mode and stage, lifecycle/status, active-format cues, validation, warnings and safe preview/interpretation output.
- Current available actions with semantic identity, truthful binding/command descriptions and stage-aware help. Layout can position descriptions, not invent available operations.
- Typed content families for editable text, hidden/masked entry, choices/trees/order, editable segments/ranges, query-and-results workflows, browser/review actions and feedback. Reuse typed subparts where semantics actually coincide.
- Stable choice/control identities; focused, selected/checked, default, disabled and locked are separate facts. Pagination and stable references remain behavior-owned.
- Editable content retains incomplete drafts, field order and native digits as needed for display. Parsed final values alone are insufficient.
- Logical active-control identity and caret position within its editable content. Layout retains that anchor through composition; the renderer derives physical placement after framing/clipping. A decorative caret glyph is not a substitute for a real editing cursor.
- Feedback state distinguishes start, running/update, phase and explicit terminal outcome/disposal. Drawing a completed bar cannot manufacture success; rendering cannot create timing or cadence semantics.

### Declarative layout rules

Use composable declarations rather than a fixed template plus proliferating flags. Layouts may compose within a typed body, not just decorate an opaque fixed rectangle. Shared typed renderers retain editing and choice semantics. Layout produces presentation data/anchors without behavioral side effects; no per-theme copies of input loops.

The layout vocabulary uses semantic style roles, not embedded palette values. Colour objects are resolved independently at render time. Exact palette roles and default/override rules belong to the factories/colour decision.

Rich and linear declarations consume the same semantic task facts where relevant, but do not share a forced identical frame. Linear presentation appends meaningful exchanges/events while preserving stable references, commands and reviewability; it does not emit an entire rich snapshot on every update. Physical terminal details and native state restoration stay in the existing backend/session module.

### Secrecy and output safety

Redact before crossing into layout. Password layouts receive only approved hidden/masked presentation, never the raw secret; masked length disclosure must remain explicit. Credential-sensitive URLs and diagnostics need the same policy. Draft redaction alone is insufficient if validation or interpretation messages reveal sensitive content. Do not expose validators/controllers to structure declarations as an escape hatch.

Help transitions preserve draft/focus/stage as resolved in [Define compact guidance and full help for every component](01-component-help-contract.md). Layout and rendering cannot consume literal answer data as new help commands or steal capture gestures.

### Source evidence

- lib/src/text_input.dart combines component/session/editor/backend code today; _edit tracks grapheme-indexed caret and command/paste semantics. Choice rendering separates focus, defaults and unavailable choices.
- lib/src/date_input.dart segmented editing requires both active-control identity and a caret inside incomplete segment drafts.
- lib/src/feedback.dart preserves explicit caller-owned lifecycle and cadence semantics; disposal and reaching total are not success.
- tool/generate_theme_atlas.py separates vocabulary, framing and specimen content, but static whole-row tuples and decorative cursor samples are not a sufficient runtime representation or behavioral contract.

### Follow-up

[Specify the internal typed presentation and layout vocabulary](06-internal-presentation-vocabulary.md) graduates the previously foggy representation question: specify concrete internal variants/primitives, family reuse, caret anchoring and linear events before per-structure declarations are finalized. Existing factory/colour and structure tickets retain their scope. Public custom-structure authoring is outside this effort.

No runtime implementation was performed.
