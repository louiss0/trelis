# Define compact guidance and full help for every component
Type: grilling
Labels: wayfinder:grilling
Status: resolved
Assignee: bvlou

## Question

Using [Current component help inventory](../help-inventory.md), what guidance contract must every component or component family expose in each interaction stage and mode? Decide compact hint content, full component-specific help coverage, access and dismissal, instruction overrides, and separation from state, review actions and visible warnings. Account for existing missing help paths and terminal fallback. Produce a per-family decision matrix, not implementation. Feedback-only components need not gain interactive help.

## Answer

Approved by bvlou through live decision rounds and explicit final confirmation.

### Guidance contract

1. The normal compact hint identifies the current stage's primary actions and the actual route to full help. It is component-aware, not a universal keyboard string. Do not imply Enter always submits: it may add a tag, enter results, or open Password actions.
2. Full component help leads with the current stage, while making accepted formats, secondary operations and the wider workflow available. Inactive controls must not be presented as currently usable. A generic editor page alone is insufficient for domain components.
3. Every interactive component needs a help route across its workflow in rich and linear interaction. Rich generally uses Ctrl+T; command-aware linear entry generally uses /help. These are conventions, not permission to reinterpret literal input. Hidden secret entry uses a safe non-text route where supported and help at its action stage. Raw gesture capture must not steal the help gesture: provide help before capture and after leaving capture, advertise the escape/back-out route, and preserve the capture semantics. Do not inject new textual commands into literal entry.
4. Opening/dismissing help preserves the draft, selection, focus and stage and does not submit an answer. Return to the same stage. When temporary help screens are unsupported, provide sequential, reviewable transcript help rather than failing or emitting unsupported cursor controls. Existing interruption and input-end semantics remain intact.
5. Minimal active-format cues remain visible when needed to interpret entry: numeric convention, date calendar/order, duration mode, etc. Full grammars, extended examples and secondary explanations belong in component help. Avoid hiding important interpretation context solely to achieve a short header.
6. Instruction presentation is theme-controlled per component, with application overrides for theme-default, compact, expanded or hidden optional guidance. A hidden-instructions setting does not remove the visible help route. Applications may add supplementary help but do not replace accurate built-in component guidance. Exact API names and default/override plumbing are deferred to the API ticket.
7. Separate optional instructions from prompt labels, current state, active-format cues, safety warnings, validation, preview/interpretation and required review/action prompts. These do not disappear under an instruction-visibility setting. Relevant warnings remain visible; themes may position and style them. Help must not disclose secret drafts or credential-sensitive values.
8. Themes may arrange and style guidance, not change controls, reserve new input gestures or change task semantics. Exact wording, visual layout and help navigation widgets remain implementation-design work; the content and discoverability requirements here are normative.
9. Feedback-only components do not gain an interactive help system merely for uniformity.

### Per-family requirements

The compact column specifies priorities, not approved literal strings or a requirement to cram every control into a single line. Actual bindings must match the active mode, stage and capability. Cancellation/back-out and interruption remain discoverable through help; raw capture explicitly advertises how to leave capture.

| Components | Compact guidance and visible context | Required full component help |
|---|---|---|
| TextInput | Submit and help; relevant constraint state | Editing including Home/End, validation constraints, cancel/interrupt, literal quoting and paste rules where applicable |
| Password | Hidden-entry to action-stage distinction, help route; conditional masking/prefill warnings | Enter opens actions rather than accepts; submit/edit/clear/cancel workflow; safe secret-entry help, literal input rules and generic validation behavior |
| Confirm / Checkbox / Toggle | Actual draft-changing gesture, completion, help; default/current draft | Kind-specific controls and linear yes/no/empty-default meanings |
| Multiline | Newline versus finish, help; relevant limits | Focus/actions, literal tab insertion, editing; linear list/edit/insert/remove/done and removal confirmation |
| Select / Radio | Navigation, choose, help; stable choice references/pages | Enabled versus focused choices, reference selection, pagination, cancel/interrupt |
| MultiSelect | Toggle, finish and help; selected count/limits | Filter, select-visible/clear-visible, selected review, paging, stable references and completion rules |
| TreeSelect | Traverse versus choose, help; current path/node context | Expand/collapse, selectable versus traversable nodes, linear open/up/choose and reference workflow |
| SortableSelect | Move/pick-up/drop versus final submit, help; order state | Locked anchors, stable reference/destination workflow, Escape revert versus cancel |
| Slider / RangeSlider | Focus, adjust and submit, help; numeric bounds/current values | Adjustment and edit actions, range minimum gap, endpoint sequencing and pair review |
| TimeInput / DateInput | Segment focus/adjustment and completion/help; active time/date format, calendar/order where applicable | Segment rules and bounds, format/digit/era details, examples, edit/review actions; time adjustment without wrapping and date-only interpretation |
| TagInput | Add versus finish and help; accepted tags/draft distinction | Draft discard, tag focus/edit/remove, casing/duplicate rules, linear commands |
| Autocomplete | Query/candidate stage actions, accept versus submit, help | Candidate inspection and acceptance, free-text submission, dismissal, asynchronous state and linear suggestion workflow |
| SearchSelect / CommandPalette / TimezoneSelect | Query versus results stage, choose/back/help; current results context | Focus transitions, entry into results does not accept, filtering/paging/stable references and relevant timezone context; wrappers retain underlying search semantics |
| MaskedInput | Slot/template context, edit/finish/help | Slot and literal rules, raw/formatted entry, correction, template ambiguity and interpretation selection |
| NumberInput / ColorInput / DurationInput | Submit/help and minimal active interpretation cues; preview state where present | Complete numeric conventions, supported colour syntax/precision, or duration grammar/mode/limits; distinguish approximate previews from accepted values |
| PortInput / IPAddressInput / EmailInput / URLInput | Primary entry action/help; interpretation context and relevant limitations/warnings | Accepted syntax, range/CIDR/zone or SMTPUTF8 conditions, credential handling and explicit absence of availability/reachability/deliverability/network guarantees |
| CronInput | Expression versus preview/review stage actions and help; active profile/preview context | Supported profile syntax and bounds, preview/edit/submit workflow, interpretation and preview limitations |
| PathInput / FilePicker / DirectoryPicker | Entry/browser/review stage actions and help; current base/location/type context; relevant safety warnings | Literal path and escaping rules, browser operations including hidden/refresh/parent, explicit link approval, review, no sandbox/later-operation guarantees |
| Keypress / KeyChordInput | Capture/declare/remove/clear/finish as appropriate, safe help route and capture back-out; provenance context | Observed versus declared/ambiguous input, reserved controls, observation requirements, capture exceptions and sequence completion |
| Text / Progress / Spinner / MultiSpinner | Information, semantic status and lifecycle rather than interaction instructions | No interactive help requirement |

### Implementation implications

- Use [Current component help inventory](../help-inventory.md) as the source baseline, not as approved replacement copy.
- Supply missing rich help for Autocomplete, fixed MaskedInput, segmented DateInput and key-capture action stages. Expand TagInput and filesystem help beyond generic editing help. Preserve capture exceptions rather than adding an unsafe universal shortcut.
- Move detailed domain guidance into real component help before compacting introductions; preserve visible active-format cues, warnings, actions and state.
- Cover both rich and linear stage behavior, temporary-screen fallback, draft restoration, literal-input handling and secret-safe output in the later verification decision.
- No runtime implementation was performed to resolve this ticket. No further child tickets surfaced: these requirements feed the existing presentation, API, structure and verification tickets.
