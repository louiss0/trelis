# Trelis

Trelis is a prompt library. This vocabulary distinguishes the user's task from the way a terminal presents it.

## Language

**Structural theme**:
The arrangement and visual grammar used to present a component, including its framing, symbols, spacing and guidance placement. It is distinct from both colour choices and the task's interaction rules.

**Colour theme**:
A set of colours assigned to presentation roles, independent of the structural theme.

**Output profile**:
Declared capabilities, geometry and display-width assumptions for a selected output. It is distinct from the chosen theme and from input or task behavior.

**Shared session**:
A coordinated presentation lifetime for one interactive prompt and independently updating feedback on the same output. It provides common help, history and cleanup without deciding the application's job outcomes.

**Live region**:
An independently updating part of a shared output presentation. Multiple live regions share the same output rather than acting as independent terminal writers.

**Interaction stage**:
A distinct part of a prompt's workflow, such as entry, browsing results, choosing actions or reviewing an answer. The available actions and relevant guidance depend on the current stage.

**Protected content**:
Information or actions that must remain available in a prompt's presentation, independently of optional instruction visibility. This includes relevant warnings, validation, essential context, required review actions and access to help.

**Compact hint**:
Brief guidance identifying the primary actions for the current interaction stage and the available route to full help.

**Component help**:
The component's controls, accepted formats and workflow guidance, led by the current interaction stage while keeping the wider task discoverable.

**Active-format cue**:
The minimal visible context needed to interpret the current entry, such as its numeric convention, calendar or date order. It is distinct from detailed format instructions.

**Supplementary help**:
Application-specific guidance added alongside built-in component help rather than replacing it.

**Civil date**:
A calendar-qualified day without a time of day or timezone. Its calendar meaning is distinct from an instant.

**Mask template**:
A declared arrangement of editable slots and literal formatting. It constrains representation without hiding secrets.

**Elapsed duration**:
A fixed span of time whose units can be converted without a calendar, anchor date or timezone.

**Calendar period**:
Unapplied calendar components, optionally accompanied by elapsed sub-day components. Its endpoint or elapsed total requires application context and is not implied by entry.

**Cron matching preview**:
A bounded set of matching instants under a declared expression profile and time context, not a promise that a scheduler will execute jobs then.

**Numeric convention**:
The active noncurrency digit, separator, grouping and sign rules that give a NumberInput entry its meaning. It remains stable during one prompt unless explicitly changed.

**Address with prefix**:
An IP address paired with a prefix length while retaining its host bits. It is not automatically the corresponding network address.

**Accessibility baseline**:
The complete set of Trelis component tasks and declared interaction/output profiles that must pass in a recorded environment before a whole-library accessibility claim is made.

**Key gesture**:
A logical key with the modifiers reported for it, rather than a physical keyboard position or global hotkey registration.

**Key sequence**:
An ordered series of one or more key gestures entered for KeyChordInput. Completion is explicit rather than inferred from a pause.

**Choice reference**:
A displayed reference that identifies the same choice throughout one prompt, independent of filtering, paging or order. It is distinct from the choice's current position.

**Locked anchor**:
An item whose position in a SortableSelect order cannot change or be crossed by a moved item.

**Selectable node**:
A tree node permitted as the answer to a TreeSelect prompt. Being expandable or traversable does not by itself make a node selectable.

**Draft answer**:
The prompt's current unsubmitted answer state. Changing it does not apply the answer to the application.

**Focused choice**:
The choice currently being inspected through navigation, which may be unavailable or not selected.

**Draft tag**:
Text being prepared for addition to a tag collection; it is not yet an accepted tag.

**Canonical tag**:
An accepted tag in the configured kebab-case or snake-case spelling. Canonical values determine duplicate identity and final tag output.

**Command-aware entry**:
Linear entry in which explicitly advertised whole-line commands are distinguished from answer data.

**Literal entry**:
Entry whose content is treated as answer data rather than prompt commands. Literal entry does not imply that the value is valid for the component.

**Feedback component**:
A presentation of information or an operation's reported state, rather than a request for a user answer. Text, Progress, Spinner and MultiSpinner are feedback components.

**Rich interaction**:
An interaction that presents changing prompt state in place, such as an active choice or editable segments.
_Avoid_: Accessible mode (rich presentation alone does not establish accessibility)

**Linear interaction**:
An interaction expressed as sequential, reviewable questions and answers, offering the same task outcome as its rich equivalent.
_Avoid_: Noninteractive mode (linear interaction still asks for answers)

**Prompt cancellation**:
Ending a prompt without accepting an answer. In rich interaction Escape may back out of transient layers first; the linear /cancel command cancels directly.

**Prompt interruption**:
Ending the whole prompt without accepting an answer, regardless of the current transient interaction layer.
