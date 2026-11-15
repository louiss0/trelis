# Trelis declarative theming and backend foundation
Status: ready-for-agent
Labels: ready-for-agent
Implementation: not started

## Problem Statement

Trelis's components are implemented, and the desired visual themes have already been chosen. Developers cannot yet apply those designs through a consistent, declarative interface because component behavior and terminal presentation are intertwined. Components print their own introductory instructions, layout and state directly, making it difficult to rearrange them or produce a compact presentation without losing useful information.

The instructions are the material the user wants compacted—not the prompt label. Existing opening text mixes keyboard guidance, accepted formats, active-format cues, warnings and review actions. Full component help is inconsistent: some components provide only generic editor help, and some rich interaction stages have no dedicated help route. Simply suppressing the introduction would remove information that users need without reliably making it available elsewhere.

The terminal foundation also lacks the shared capability, display-measurement and screen-composition infrastructure needed to support the designs safely. Cursor support does not establish colour depth, Unicode glyph support or display-cell width. Independent prompts and feedback can interfere if they repaint the same output without coordination.

Developers need named structural themes, independently configurable colour themes, compact and discoverable component help, and a reliable shared backend. This must preserve the existing component tasks, answer types and explicit outcomes rather than creating a separate behavior implementation for every visual variant.

## Solution

Implement and validate the shared backend first. Give prompts and feedback one capability-resolution, display-measurement, rendering and event-delivery foundation, plus explicit shared sessions containing one interactive prompt and multiple feedback live regions. Validate this foundation with actual components using a plain reference presentation before beginning the named-theme rollout.

Then expose the fifteen existing structural themes as public classes with static, typed component factories. Keep colour themes separate, provide complete immutable colour objects and named existing palettes, and allow per-component colour overrides. Structural themes declaratively arrange typed presentation content without consuming input or changing component behavior.

Replace unconditional verbose introductions with component-aware compact hints that identify primary actions and lead to complete component help. Keep protected content available independently of optional instruction visibility. Applications can override instruction presentation and add supplementary help without replacing the built-in guidance.

Use automated regression tests, Windows/Linux/macOS CI and native terminal checks, and an agent-operated visible Windows terminal probe. Linux/macOS verification is CI-only: physical access is not required. No human checkpoint is required. Theme integration remains blocked until the backend evidence gate has actually passed.

## User Stories

1. As a library consumer, I want to choose an already-defined structural theme by name, so that I can apply its visual grammar without rebuilding prompt behavior.
2. As a library consumer, I want each structural theme exposed as a separate class, so that available presentation choices are discoverable through the language and editor.
3. As a library consumer, I want static methods named after the components, so that I can create a configured component directly from its structural-theme class.
4. As a library consumer, I want those methods to return concrete component objects, so that I retain their existing invocation and lifecycle interfaces.
5. As a library consumer, I want factory arguments and defaults to match the existing constructors, so that selecting a structure does not silently change validation or configuration.
6. As a library consumer, I want generic choice types and accepted answer types preserved, so that theming does not weaken type safety.
7. As an existing application maintainer, I want direct constructors to remain supported, so that adopting the new backend does not require rewriting every component call.
8. As an existing application maintainer, I want the new default presentation and migration differences documented, so that transcript changes are intentional and reviewable.
9. As a library consumer, I want structural themes separate from colour themes, so that I can combine a layout with any supported palette.
10. As a library consumer, I want terminal-native colours by default, so that Trelis does not assume a dark or light terminal surface.
11. As a library consumer, I want complete immutable colour-theme objects, so that the same palette behaves predictably across structures.
12. As a library consumer, I want to derive a palette using copyWith, so that I can alter selected roles without mutating an existing palette.
13. As a library consumer, I want per-component colour overrides, so that one component can differ without changing neighboring components.
14. As a library consumer, I want the existing atlas palettes available as named colour objects, so that I can reuse the chosen colours independently of structural classes.
15. As a terminal user, I want non-colour indicators for focus, selection, warnings and errors, so that monochrome output remains understandable.
16. As a terminal user, I want colour requests to respect the output's capabilities and colour-disabled settings, so that unsupported escape sequences do not corrupt the display.
17. As a user reviewing redirected output, I want no ANSI sequences in the log, so that the transcript is portable and readable.
18. As a CLI user, I want short instructions instead of a large introduction above every input, so that the task remains visually clear.
19. As a CLI user, I want compact hints to identify the current stage's primary actions and help route, so that I can begin without reading a manual.
20. As a CLI user, I want the hint to distinguish submission, adding an item and entering a review stage, so that pressing Enter does not surprise me.
21. As a CLI user, I want full component help to start with the current interaction stage, so that its immediate guidance is relevant.
22. As a CLI user, I want accepted formats and the broader workflow available from component help, so that compact guidance does not leave me guessing.
23. As a CLI user, I want a minimal active-format cue to remain visible, so that I can interpret a date, number, duration or other formatted entry correctly.
24. As a CLI user, I want warnings, validation and required review actions to remain visible or directly reviewable, so that hiding optional instructions does not conceal important information.
25. As an application developer, I want themes to choose instruction defaults per component, so that guidance fits the component and structure.
26. As an application developer, I want instruction-presentation overrides, so that I can request compact, expanded or hidden optional guidance when appropriate.
27. As an application developer, I want to add supplementary help, so that application-specific context can accompany accurate built-in instructions.
28. As a CLI user, I want help to preserve my draft answer, focus and caret, so that learning the controls does not discard my work.
29. As a CLI user, I want reviewable transcript help when a temporary help screen is unsupported, so that help does not depend on one terminal feature.
30. As a user entering a secret, I want help access not to reinterpret my literal secret as a command, so that secret entry remains correct and private.
31. As a user capturing a key gesture, I want help not to steal the gesture I intend to capture, so that capture semantics remain truthful.
32. As a user of feedback components, I want information and status without an artificial help interaction, so that noninteractive feedback remains lightweight.
33. As a backend maintainer, I want component behavior separate from structural presentation, so that fixes apply to every theme.
34. As a backend maintainer, I want immutable typed presentation content rather than anonymous strings, so that layouts retain the meaning of choices, segments and editable regions.
35. As a backend maintainer, I want secrets redacted before layout, so that a structure cannot accidentally render raw private state.
36. As a backend maintainer, I want a small internal composable layout vocabulary, so that existing structures are expressible without building a public widget framework.
37. As a terminal user, I want omitted protected content inserted into a safe presentation area, so that a faulty layout does not silently hide a warning or required action.
38. As a library maintainer, I want declaration tests to report that omission even when runtime repair succeeds, so that fallback does not conceal a broken theme.
39. As a CLI user, I want focused, selected, default and unavailable choices distinguished, so that inspection does not imply acceptance.
40. As a CLI user, I want choice references to retain their established meaning through filtering and paging, so that presentation changes do not select a different answer.
41. As a user editing segments or masks, I want incomplete draft fields and the active segment preserved, so that the layout supports real editing rather than only final parsed values.
42. As a CLI user, I want the real caret to follow the active editable region through framing and clipping, so that the displayed editing position is correct.
43. As a CLI user, I want readable content to wrap and editors to scroll appropriately, so that narrow terminals remain usable.
44. As a CLI user, I want ornament reduced before essential information, so that a small terminal does not sacrifice task correctness to borders.
45. As a CLI user, I want layouts to reflow while I am idle after a resize, so that I do not need to type a key to repair the display.
46. As a CLI user, I want my draft and focus preserved during resize, so that geometry changes do not alter my answer.
47. As an application developer, I want a shared OutputProfile model for prompts and feedback, so that capability rules do not differ between component families.
48. As an application developer, I want automatic detection with typed overrides, so that unusual terminals and deterministic scripted outputs can declare their capabilities.
49. As an application developer, I want profile resolution to use the selected output, so that a terminal on stdout does not incorrectly enable rich output on redirected stderr.
50. As a test author, I want explicit synthetic dimensions and capabilities, so that tests do not depend on an invented screen or the developer's environment.
51. As an application developer, I want explicitly requested rich interaction to fail clearly when unsupported, so that the library does not silently reinterpret a requirement as a preference.
52. As an application developer, I want automatic mode to choose a safe fallback, so that capable and incapable outputs can use the same application flow.
53. As a backend maintainer, I want a pinned and documented Unicode measurement basis, so that width behavior changes are controlled and reproducible.
54. As a user entering Unicode text, I want editing boundaries distinguished from display-cell width, so that accents, CJK and emoji do not break caret placement.
55. As an application developer, I want an explicit ambiguous-width policy, so that a known terminal configuration can select its appropriate width assumption.
56. As a user reviewing linear interaction, I want meaningful ordered events rather than repeated frame dumps, so that the transcript stays readable.
57. As a user reviewing linear interaction, I want a new help request or validation occurrence preserved even when its wording repeats, so that legitimate actions are not lost through text-based deduplication.
58. As a user reviewing linear interaction, I want repaints and resizing not to duplicate earlier messages, so that display maintenance does not look like new task activity.
59. As an application developer, I want an explicit shared session, so that output ownership and cleanup are visible in my application's structure.
60. As an application developer, I want one prompt and several feedback regions on the same output, so that background work can remain visible while the user answers a question.
61. As a CLI user, I want feedback updates not to steal my input or caret, so that concurrent status updates do not disrupt editing.
62. As an application developer, I want a second active prompt rejected before it consumes input, so that two prompts cannot race for the same keyboard.
63. As a CLI user, I want feedback stacked above the active prompt in stable order, so that the shared screen remains predictable.
64. As a CLI user, I want a session-modal help view while background work continues, so that help remains readable without pausing application jobs.
65. As a CLI user, I want dismissal to restore the latest feedback and prompt state, so that completed work is not replaced by a stale screen.
66. As a CLI user, I want the prompt prioritized when the terminal is short, so that background status does not make the current question unusable.
67. As a CLI user, I want important overflow notices preserved in history with visible severity indicators, so that compressed feedback does not hide failures.
68. As an application developer, I want coordinated informational messages through the session, so that logging through supported interfaces does not overwrite the active editor.
69. As a script author, I want sequential prompts to share one ordered input source correctly, so that closing one prompt does not lose input intended for the next.
70. As an application developer, I want each component's explicit outcome preserved, so that cancellation, interruption, input end and unavailability remain distinct.
71. As an application developer, I want progress and feedback lifecycle preserved, so that a displayed percentage or disposal does not invent success.
72. As an application developer, I want unfinished regions disposed without assigning job outcomes, so that the application remains responsible for its work.
73. As an application developer, I want local region faults isolated where possible, so that one presentation failure does not unnecessarily erase unrelated feedback.
74. As an application developer, I want a shared output failure to trigger safe session cleanup, so that stale regions cannot continue writing to a broken destination.
75. As a terminal user, I want terminal modes, styles and resize watchers restored or released on supported exit paths, so that the shell is not left damaged after a prompt.
76. As a maintainer, I want backend acceptance to block theme integration, so that the visual rollout is not built on unverified infrastructure.
77. As a maintainer, I want fresh Windows, Linux and macOS automated/native evidence, so that platform support is based on execution rather than configured workflows.
78. As a maintainer without physical Linux or macOS access, I want those platform checks to run in CI, so that verification does not require unavailable hardware or manual access.
79. As a maintainer, I want an agent to exercise the backend in a visible Windows terminal, so that display regressions receive observational checks without a human checkpoint.
80. As a maintainer, I want screenshots and available NVDA observations labelled accurately, so that automation evidence is not misrepresented as human usability or accessibility qualification.
81. As a maintainer, I want every component tested across every structure, so that smaller component families are not omitted from theming support.
82. As a maintainer, I want palette mapping tested independently of the full interaction matrix, so that colour independence is verified without a redundant Cartesian explosion.
83. As a maintainer, I want evidence tied to revisions and environments, so that an old successful run cannot qualify a newer implementation.
84. As an implementation agent, I want individually scoped tasks with dependencies and acceptance criteria, so that backend-first work can begin without reopening design decisions.
85. As a maintainer, I want pending and failed checks to remain visible blockers, so that creating a plan or skipping a test is never mistaken for acceptance.
86. As a library consumer, I want theme integration to preserve rich and linear task equivalence, so that choosing a presentation does not change the answer I can provide.

## Implementation Decisions

### Delivery order and compatibility

- Implement capability resolution, measurement, typed rendering, ordered events, shared input routing and session composition before the named-theme rollout.
- Migrate all 38 existing components through a plain reference presentation to prove the backend with actual component behavior. This reference path is a backend prerequisite, not permission to begin all fifteen named structural themes early.
- Use the separately defined sixteen-task backend sequence, ending with an explicit evidence audit. The theme rollout remains blocked until that audit accepts the current implementation.
- Preserve existing constructor arguments/defaults, generic parameters, callbacks, answer/value types, cancellation/interruption/input-end/unavailable outcomes, command/literal distinctions, paste provenance, validation and async freshness semantics.
- Preserve decimal-string slider answers, range/time records, nullable accepted number/colour values, and component-specific interpretation rules rather than introducing a common loosely typed answer.
- Keep construction and structural factory calls free of terminal acquisition, output, answer validation and async work. Invocation starts a fresh component lifecycle.
- Keep direct component construction supported. Its default structural presentation is PlainTheme, with terminal-native colours. Document intentional presentation and synthetic-rich compatibility changes.

### Structural-theme interface

- Expose exactly the chosen structural classes: RailTheme, MinimalTheme, AsciiTheme, BoxTheme, BracketTheme, RoundTheme, FormTheme, ChevronTheme, PlainTheme, DoubleTheme, BranchTheme, LineTheme, BlockTheme, LedgerTheme and ColonTheme.
- Each class provides static lower-camel-case methods matching the 38 implemented component names and returning their existing concrete types. Preserve generic selection types and exact typed forwarding, including acronym spellings such as ipAddressInput and urlInput.
- Interactive factories add colours, instruction presentation and supplementary help. Feedback factories add colours without irrelevant instruction/help parameters.
- Session, mode, source, output and output-profile configuration belong to invocation, not structural factories. Factories configure shared behavior; they do not introduce structure-specific input loops.
- Keep declarative structure definitions internal. Public custom structural authoring and a general-purpose layout framework are not required.

### Colour themes

- ColorTheme is a complete immutable palette with ten roles: foreground, background, muted, accent, selectionForeground, selectionBackground, success, warning, error and border.
- Custom construction requires all roles. copyWith returns a complete new object while preserving unspecified roles. A component's explicit colour object replaces its default palette; it does not implicitly merge with structure colours.
- TerminalColor represents terminal-default, indexed colour or opaque RGB. Validate indexed/channel bounds; do not accept arbitrary escape-sequence strings as colours.
- All structures default to ColorThemes.terminalDefault. Do not assume a terminal surface colour or mutate global theme state.
- Expose the 45 existing atlas palettes as named immutable colour objects, separately from structural classes. Preserve their existing RGB values.
- Map terminal surface to background, text to foreground, muted/accent/success/error/rule to their corresponding roles, selected text to selectionForeground and accent to selectionBackground. Use accent for the initial warning role because the atlas has no dedicated warning token; retain a warning indicator. Ignore webpage background.
- Keep focus/selection/warnings/errors meaningful without colour. Apply backgrounds only to owned component/compositor cells and restore styles at coordinated output boundaries.

### Instructions and component help

- InstructionDisplay supports themeDefault, compact, expanded and hidden. Structural themes choose per-component/stage defaults; application overrides take precedence for optional guidance only.
- The normal compact hint identifies the current stage's primary actions and actual help route. Enter must not be advertised as submission when it adds a tag, enters results or opens Password actions.
- Full component help leads with the current stage and provides formats, secondary operations and broader workflow guidance. Generic editing help alone is insufficient for specialized inputs.
- Supplementary help augments accurate built-in help; it does not replace controls, remove required guidance or rewrite input semantics.
- Keep prompt labels, state, active-format cues, relevant warnings, validation, interpretation and required review/action content separate from optional instruction copy. Hidden instructions retain help access and protected content.
- Rich interaction generally uses Ctrl+T and command-aware linear interaction generally uses /help. Preserve explicit exceptions for literal secret entry and raw key capture; never steal answer data to enforce a universal help binding.
- Help preserves the draft answer, logical focus and caret, subject to legitimate behavior-owned state changes. Use transcript help when a temporary screen is unsupported.
- Complete missing rich help paths and domain-specific guidance before suppressing the corresponding verbose introduction. Feedback components do not gain artificial interactive help.

### Presentation modules and declarative vocabulary

- Component behavior owns editing, validation, navigation, action meanings, stages, help availability/content, source identities, async lifecycle and results.
- A presentation projection produces immutable display-safe content before structural layout. It exposes no raw secrets, mutable controllers, validators, input handlers or behavior-performing callbacks.
- Typed bodies cover text, hidden/masked entry, boolean/choices, tree/order extensions, segments/ranges, tags, query/results, browser/review, feedback and composites. Preserve incomplete drafts and distinct focused/selected/default/unavailable/locked states.
- Layout uses a bounded vocabulary of rows, columns, padding, gaps, rules, frames, rails, semantic text runs, identified content slots, typed item/field templates and dedicated editable regions.
- Editable regions carry stable field identity and logical caret information. Ordinary spans do not compete to own the caret. A decorative cursor glyph is not a replacement for the real editing cursor.
- The shared compositor tracks protected content actually placed by a declaration and inserts missing relevant content into a deterministic safety area near the body before optional hints. Declaration coverage checks still report omissions.
- The renderer owns cell measurement, wrapping/clipping, physical placement, semantic colour resolution and terminal output. Native session adapters remain the sole terminal-mode acquisition/restoration owners.

### Views, events and identity

- An immutable current view supports rich painting; explicit ordered presentation events support sequential history. A view revision is not automatically a new history event.
- Events represent meaningful stage/state/caret changes, validation/notices, requested help, review/interpretation and reported lifecycle outcomes. Repaint, resize and no-op keys do not create duplicate history.
- Identify sessions, regions, controls, content and event occurrences independently of labels, message text or sensitive values. Repeated help requests/errors remain new occurrences even when wording matches.
- Preserve SearchSelect's source-stable choice references and Autocomplete's response-local candidates as different identity models. Behavior rejects stale/closed-session responses before projection.
- Do not infer acceptance, progress completion, retry availability or missing help actions by diffing display snapshots.

### Output profiles and capability policy

- Expose immutable OutputProfile configuration with automatic defaults and independent cursor, alternate-screen, monochrome-style, colour-depth, glyph, geometry and ambiguous-width declarations.
- Resolve fields in order: invocation profile, scripted-source profile, applicable legacy supportsRich hint, selected-output observations/advertisements, conservative defaults.
- Query the actual selected output and distinguish observed facts, caller declarations, unknown values and resolved policy. A different terminal stream cannot supply capabilities for the chosen output.
- Known real-stream redirection, TERM=dumb and failed native acquisition remain restrictions. Nonempty NO_COLOR suppresses colour even with an explicit palette/profile; an empty value does not. Independently supported cursor and monochrome styling remain separate.
- Preserve explicit rich-mode failure: prompts report Unavailable and feedback start uses its existing StateError shape. Automatic mode may select linear. Missing colour or Unicode alone does not prevent safe ASCII/monochrome rich interaction.
- Keep existing supportsRich inputs as compatibility hints only. They do not prove colour, glyph support, alternate-screen support or dimensions.
- Synthetic rich output must declare sufficient profile facts and positive geometry. Do not invent a legacy virtual screen. Update scripted fixtures and migration documentation explicitly.
- Fixed geometry requires positive dimensions; real measured bounds constrain a requested viewport. Failed or zero observations do not become fabricated measurements.
- Observe resize while idle, coalesce changes, refresh safely and stop watchers on teardown. Defer geometry-dependent painting when placement cannot be established while preserving logical state and supported interruption/cleanup behavior.

### Unicode and colour rendering

- Pin termunicode at 0.2.0 behind a Trelis-owned adapter using its public scalar/property APIs and Unicode 16 table basis. Retain characters segmentation. Do not adopt its known-problematic string-width helper as a drop-in oracle.
- Define and regression-test supported cluster rules, unsupported visible representations, tab expansion, hard-line boundaries and original-grapheme-to-display/caret mapping.
- Cover combining text, CJK, ambiguous width, flags/modifiers, supported ZWJ/variation/keycap forms and isolated unsafe/zero-advance content. Default ambiguous width to narrow with an explicit wide override.
- Encode control/bidi/escape content safely without altering underlying answer data. Hidden presentation exposes neither secret text nor secret length/caret metadata; masking is an explicit disclosed alternative.
- Treat width policy as a versioned compatibility assumption, not proof of universal terminal/font agreement.
- Preserve supported indexed references and terminal-default colours. Approximate RGB deterministically for lower colour levels using documented standard palettes, squared RGB distance and stable tie-breaking; customized ANSI slots are not measured RGB facts.
- Emit semantic monochrome output when colour capability is absent. Real redirected output contains no ANSI, even when a named RGB palette is supplied. Explicit synthetic recording sinks are a separate test contract.

### Rich and linear structural presentation

- Retain the approved fifteen grammars rather than treating them as colour variants of one fixed rectangle. Compose inside typed bodies as well as around them.
- Preserve continuous/branching rails, conversational minimal form, ASCII console, square/rounded/double enclosures, bracket/chevron headings, fixed-label form, plain question, underline, reverse-video label, numbered ledger and diagnostic colon structure.
- Follow established hint placement: enclosures put compact hints outside below; rails close around the hint; other structures retain their approved prefixes and indentation.
- Rich views and meaningful stage/help/review boundaries use full structural framing. Smaller linear updates use matching compact event blocks rather than repeatedly dumping a rich frame.
- Size to safe meaningful content with an 80-column total-width cap bounded by actual output width. Keep geometry stable during typing; recompute for stages or actual resizing.
- Preserve the choice breathing row when space permits. Wrap read-only content, scroll single-line editors around their caret, preserve multiline hard breaks and reduce chrome before essential content.
- Keep semantic focus order, choice references and action meanings unchanged when fields stack or regions clip. Preserve overflow indicators without inventing navigation controls.
- PlainTheme and AsciiTheme always use ASCII. Other structures have defined ASCII counterparts for unknown/unsupported glyph support without changing the selected interaction mode.
- Ledger numbers meaningful stages locally per invocation; help/repaints do not increment them and returning to a stage retains its number. There is no cross-prompt global counter.
- Decorative title treatment never case-transforms answers, literal commands, examples or references. Completion displays an actual reported outcome and approved safe summary, not automatic value stringification.

### Shared sessions and live regions

- TerminalSession.run provides an explicit scoped asynchronous session and returns its callback result after coordinated output and cleanup. Add session attachment to component invocation, not construction.
- The session owns selected output, input source, mode/profile and a serialized writer. Attached invocations reject competing configuration rather than negotiate different physical output facts per region.
- Permit one interactive prompt plus multiple feedback live regions. Reject a second active prompt before input consumption; do not broadcast keystrokes or silently queue overlapping prompts.
- Acquire input lazily for the active prompt. Keep one session-owned scripted source/router across sequential prompts so region teardown does not close, resubscribe or lose buffered input.
- Stack feedback above the prompt in stable registration order. Feedback repaint restores the prompt's physical caret from its logical anchor without changing the draft.
- Coordinate session-wide modal help and alternate-screen transitions. Background work continues; dismissal restores the latest composite state and preserves significant notices from the modal interval.
- Compact running feedback before sacrificing the prompt at short heights. Preserve important notices in full reviewable history and retain visible severity indicators; do not conceal them only in help.
- Coordinate informational Text output above/reconciled with the live area. Arbitrary external writers and opaque aliases cannot be made safe automatically.
- Standalone calls use temporary sessions through the same implementation. They do not silently join another shared screen; ownership conflicts produce clear errors.
- Explicit feedback outcomes commit once and remove live regions. Progress totals do not imply success; unfinished disposal/scope exit does not cancel application jobs or assign outcomes.
- Isolate local region faults where possible; shared writer/output failure closes the session safely. Retire generations, drain output, stop watchers, release leases and restore received terminal state on supported exits.
- Preserve callback failure context when cleanup also fails. Closed handles cannot start new work, and retired updates cannot revive output. Do not promise recovery after forcible process termination or unmanaged external terminal mutation.

## Testing Decisions

### Primary seam and test quality

- The primary acceptance seam is the existing public component invocation surface, extended by the approved shared-session interface. Exercise actual prompt, presentation and feedback lifecycles with explicit scripted input/output profiles rather than adding a separate public testing framework.
- These seams were agreed during the design work; no new user interview or seam-selection decision is required.
- A good test supplies input/configuration and observes accepted values, explicit outcomes, emitted presentation/history, caret behavior, resource restoration and timing visible at the interface. It does not inspect mutable private controller fields, depend on internal call counts or assert incidental implementation class names.
- Pure capability, measurement, encoding, colour and event modules may be tested directly through their narrow contracts. Their algorithms need deterministic adversarial fixtures, but those fixtures do not replace end-to-end public behavior tests or require making internal layout types public.
- Inject selected-output observations, environment, geometry, clocks, resize events, input and failing sinks. Tests must not depend on the developer's actual terminal, locale, process environment or font.
- Retain prior art from the existing public rich/linear acceptance matrix, component-specific Dart suites, Windows native and ConPTY harnesses, POSIX PTY checks and documented editable-terminal probes.
- Use semantic/frame snapshots as supplementary structure checks. Do not approve behavior changes by blindly regenerating goldens or treat static atlas specimens as executable input contracts.

### Backend module and interaction coverage

- Test profile/source/legacy/detection precedence, selected stderr/stdout independence, redirected/dumb/unknown outputs, size exceptions, invalid/zero geometry, explicit synthetic profiles, independent capability combinations and NO_COLOR absent/empty/nonempty.
- Test pinned width/display policy with actual scalar/cluster fixtures, unsupported representations, mappings, clipping and caret placement, not only character counts. Retain probes demonstrating the rejected helper edge cases as regression evidence.
- Test immutable safe projections, typed semantic distinctions, protected-slot insertion and omission diagnostics. Test custom/default/indexed/RGB colour behavior, deterministic approximation, local backgrounds, state restoration and no ANSI in real redirected output.
- Test ordered event identities, fresh identical-text occurrences, absence of repaint duplicates, meaningful caret-only changes and sequential scripted input without source loss.
- Test shared ownership, stable registration/removal, one prompt with many feedback producers, second-prompt rejection, standalone behavior, Text messages, callback failures, late updates and closed handles.
- Test idle resize, short/narrow/unknown geometry, feedback summaries with preserved important history, modal help during background updates and latest-state/caret restoration.
- Test every existing component's public tasks, validation, answer types and explicit outcomes. Preserve async freshness, choice-reference identity, segmented incomplete drafts, capture exceptions and feedback cadence/lifecycle.
- Use synthetic secret canaries. Assert unmasked private data and undisclosed length/caret information are absent from projections, output/history and diagnostics; test explicit masking/prefill warnings and component-approved interpretation behavior separately.
- Fault-inject acquisition, rendering, writing, callbacks and restoration. Verify isolation or session-wide failure as appropriate, cleanup on all supported exits and preservation of original failure context.

### Backend evidence gate

- Require fresh format, analysis, documentation-link and Dart test results plus native-terminal scenarios on Windows, Ubuntu and macOS CI at the accepted revision.
- Linux/macOS native PTY verification runs in CI. No physical access, local GUI inspection or human confirmation on those platforms is required.
- Extend native scenarios to exercise the new capability, measurement, session, resize and failure paths. Existing workflow configuration, historical runs and syntax-only script checks are not current evidence.
- An agent exercises the implemented backend in a visible Windows terminal using the installed computer-use skill and version-matched tooling. Cover keyboard editing, caret movement, shared feedback, informational writes, help/dismissal, idle/narrow resize, ASCII/no-colour output, secrets and repeated/error/cancellation cleanup.
- Capture screenshots and expected/observed notes. Capture NVDA speech where available and explicitly identify missing speech evidence. Agent-generated input is not physical keyboard or human usability evidence.
- No human checkpoint is required. Missing GUI/tool availability leaves that gate blocked rather than silently substituting unit tests or requiring a person.
- Record source revision, environment, SDK/terminal/tool versions, selected streams, effective profile/geometry/width policy, commands, expected/actual results, artifacts and limitations. Distinguish pass, fail and pending; required unexecuted checks block acceptance.
- Only an explicit current-revision evidence audit opens the backend gate. Re-run affected checks after fixes; old successful runs do not qualify newer code. Neither this specification nor its ready-for-agent label represents an implementation pass.

### Theme verification after backend acceptance

- Verify all 38 methods on all 15 structural classes: 570 typed factory pairs. Compile call fixtures and use distinguishable non-default arguments to test forwarding and construction-time purity.
- Require visible presentation/task smoke coverage for all 34 interactive components in both modes across all structures: 1,020 paths.
- Require both modes for the three live feedback components across all structures: 90 paths. Text has 15 mode-independent presentation paths, not two distinct renderers.
- The minimum distinct presentation/task matrix is therefore 1,125 paths, plus factory coverage and deep semantic/stage/help/secret/resize regressions. Supplied-answer validation that bypasses rendering cannot stand in for a render/task path.
- Verify all 45 palette mappings and immutable override/conversion rules independently. Add cross-structure integration checks, but do not multiply the entire interaction matrix by every palette.
- Check each grammar's placement, state markers, ASCII counterpart, sizing, ledger sequencing, help, protected content and completion policy. Inspect representative normal/narrow visible output through agent computer use.
- A theme-phase backend regression reopens the affected backend evidence; do not bypass it by relaxing snapshots.

## Out of Scope

- Selecting new visual themes or redesigning the existing atlas directions.
- Beginning the named-theme rollout before backend acceptance.
- Implementing this feature merely by publishing this specification.
- Several simultaneously interactive prompts, cross-prompt focus switching or broadcasting input.
- Public custom structural-theme authoring, caller-declared grids or a general-purpose widget/screen framework.
- Automatic global shared screens, mutable global theme defaults or one behavior class per structure/palette pair.
- Cross-prompt Ledger flow numbering or caller-supplied step configuration.
- Fabricated task outcomes, automatic cancellation of application jobs or a new application-level cancellation framework.
- Prototype-only component APIs that are not among the 38 implemented components.
- A package/import rename or unrelated domain/API redesign.
- Physical Linux/macOS verification, a human checkpoint, universal font/terminal width guarantees or whole-library accessibility qualification.
- Guaranteed coordination with arbitrary external terminal writers or restoration after forcible process termination.

## Further Notes

This specification is published to the repository's local Markdown issue tracker and labelled ready-for-agent. Readiness means the design and execution route are specified; implementation and evidence remain outstanding.

The existing decision tickets remain the detailed decision history. This document synthesizes them without reopening their choices. No relevant ADR directory was found in the inspected documentation; the project glossary supplies the terminology.

Implementation begins with [Capture the backend regression baseline and deterministic harness](../trelis-backend-implementation/issues/01-regression-baseline-and-harness.md). Follow the existing backend tasks rather than creating a parallel competing backlog.

Supporting artifacts:

- [Completed Trelis theming decision map](map.md).
- [Backend-first implementation specification and acceptance matrix](../trelis-backend-implementation/spec.md).
- [Backend task dependencies](../trelis-backend-implementation/dependencies.md).
- [Explicit backend acceptance gate](../trelis-backend-implementation/issues/16-backend-evidence-gate.md).
- [Gated theme-integration handoff](../trelis-theme-integration/spec.md).
- [Source API baseline](api-baseline.md).
- [Expanded typed factory-signature notation](factory-signatures.md).
- [Current component help inventory](help-inventory.md).
- [Capability and Unicode-width research, source audit and executed temporary probes](../../../doc/research/trelis-output-capabilities-and-width.md).

The source inventory was captured at revision 80f4752e16a6e3b2451f2b87b9450e535ae3fa30 and must be checked against the implementation revision. Temporary package probes are research evidence only; they do not establish that the new backend, platform matrix or GUI gate has passed.
