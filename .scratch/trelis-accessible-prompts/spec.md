# Trelis accessible terminal prompt components

Status: ready-for-agent
Labels: ready-for-agent
Parent: [Trelis accessible prompt interaction specification](map.md)

## Problem Statement

Trelis is a prompt library whose visual atlas demonstrates many possible
terminal interactions, but those static pictures do not specify usable behavior.
A library consumer needs components with explicit construction, editing,
selection, validation and completion semantics rather than component-shaped
renderings.

An interactive terminal user needs to complete prompts predictably with the
keyboard. Terminal key input is not a GUI event model: traditional encodings
collapse some key combinations, platform/screen-reader shortcuts can intercept
others, and physical key availability does not prove that an application can
observe it. A terminal's ability to render ANSI sequences is not proof that a
screen reader can use its content.

A screen-reader user needs labels, current state, errors, choices and outcomes
to remain discoverable and reviewable. Rich in-place updates and sequential
linear interaction must offer equivalent task outcomes, with explicit capability
boundaries rather than undisclosed degradation or unsupported accessibility
claims.

The component set also needs safe interpretation of structured values. Locale,
calendar, number, URL, address, color, path, mask, duration and cron syntax can
change meaning. Parser permissiveness, normalization, browser-style repair or
network activity must not silently substitute for the prompt's declared
contract.

## Solution

Implement Trelis as a set of public component classes constructed before use and
explicitly invoked to conduct a prompt or present feedback. Use positional
parameters where appropriate, records for coherent grouped data/settings, and
validated record extension types instead of option-holder classes. A component
instance does not acquire input, render or change terminal state merely by being
constructed.

Each interactive component supports rich and linear interactions with equivalent
task outcomes. Mode choice respects the current user's explicit choice, then
saved user preference, application preference and automatic capability-based
selection. Prompt and feedback output uses the application's standard error
stream by default while leaving its standard output available for results.
Input-source use is explicit and cannot consume application data implicitly.

All components use shared editing, cancellation, interruption, submission,
validation, literal-input, paste and terminal-restoration rules. Component
contracts add only their necessary exceptions, with portable and discoverable
actions instead of relying on mouse input, decoration, color, animation or an
enhanced keyboard protocol alone.

Development begins with small Windows Terminal + NVDA feasibility probes for the
shared foundations before bulk component implementation. Automated tests target
the public component interaction boundary; native integration tests and real
NVDA qualification remain separate evidence. Only actual task completion in the
exact recorded environment can support a whole-library accessibility claim.

## User Stories

### Library consumers constructing and invoking components

1. As a library consumer, I want every component to be a class, so that its behavior and lifecycle have an explicit object boundary.
2. As a library consumer, I want to construct a component before invoking its prompt or presentation method, so that configuration is separate from terminal interaction.
3. As a library consumer, I want positional component parameters where useful, so that common construction remains concise.
4. As a library consumer, I want records for related settings and data, so that a coherent group has one value shape without an option class.
5. As a library consumer, I want named record fields for non-obvious relationships, so that a value such as bounds or path context is self-describing.
6. As a library consumer, I want invariant-bearing record groups wrapped in extension types, so that validation is part of the grouped value's boundary.
7. As a library consumer, I want record validation to go through a private parsing path, so that I cannot bypass invariants with an unvalidated raw record.
8. As a library consumer, I want invalid configuration reported at creation, so that programming mistakes do not become silent changes to the requested interaction.
9. As a library consumer, I want ordinary user validation errors kept separate from configuration errors, so that people can correct input without treating the prompt as broken.
10. As a library consumer, I want to reuse component configuration through fresh invocations, so that each session has defined initial state and does not replay an earlier answer implicitly.
11. As a library consumer, I want concurrent use of one component instance rejected or prevented, so that competing input/output ownership cannot corrupt its session.
12. As a library consumer, I want records for accepted multi-field answers, so that related answer fields remain together with value semantics.
13. As a library consumer, I want success, cancellation, interruption, input-ended and unavailable to be distinct outcomes, so that I cannot accidentally treat one as another.
14. As a library consumer, I want to own application exit and the consequences of accepted answers, so that invoking a prompt never exits my program or executes a command for me.
15. As a library consumer, I want all required component constraints stated in its contract, so that I can supply a valid configuration without discovering hidden parser behavior.
16. As a library consumer, I want an explicitly unsupported configuration to be unavailable rather than silently approximated, so that I can choose a supported alternative deliberately.
17. As a library consumer, I want mode selection to respect the current user's explicit choice and saved preference before application defaults, so that accessibility preferences are not silently overridden.
18. As a library consumer, I want rich mode chosen automatically only when its required capabilities exist, so that capable terminals receive rich interaction and others receive linear interaction.
19. As a library consumer, I want an explicitly requested unavailable rich interaction to fail before partial setup, so that I can explain or correct the environment without a hidden downgrade.
20. As a library consumer, I want prompt and feedback output on stderr by default, so that stdout remains available for application-owned results and pipelines.
21. As a library consumer, I want explicit input-source selection, so that piped data or supplied answers are not confused with interactive commands.
22. As a library consumer, I want redirected prompt output to be stable text without cursor addressing or animation, so that logs and transcripts remain meaningful.
23. As a library consumer, I want a distinct input-ended outcome when an explicitly selected input stream reaches EOF, so that incomplete data is not accepted or treated as cancellation.
24. As a library consumer, I want defaults to be actual editable values, so that people can inspect, modify or erase them instead of accepting an uneditable placeholder.
25. As a library consumer, I want a selected editor/mode that cannot prefill a required default to report unavailable, so that the default's meaning is not weakened to a pending-value workaround.
26. As a library consumer, I want local validation by default and explicit opt-in for network or environment checks, so that prompting does not unexpectedly disclose data or depend on connectivity.
27. As a library consumer, I want exact backend/editor/provider revisions and their qualified limits to be explicit, so that documentation of a similar package is not mistaken for working support.

### Interactive keyboard and editing users

28. As a keyboard-only user, I want to complete every essential task without a mouse, so that terminal interaction does not exclude my input method.
29. As a keyboard-only user, I want ordinary Left/Right, Backspace/Delete and line-boundary editing behavior, so that I can correct text predictably.
30. As a keyboard-only user, I want editing and deletion to operate on user-perceived grapheme clusters, so that one action does not split an accented or joined character unexpectedly.
31. As a keyboard-only user, I want user-facing character limits counted in graphemes while display width is handled separately, so that emoji and combining sequences are not mistaken for byte or column counts.
32. As a keyboard-only user, I want essential actions not to depend solely on modified Enter, arrows or unavailable platform shortcuts, so that legacy and intercepted keys do not make a prompt unusable.
33. As a keyboard-only user, I want optional GUI-style and enhanced-protocol shortcuts to supplement the baseline, so that useful accelerators never become the only completion path.
34. As a keyboard-only user, I want Enter normally to validate and submit the current answer, with explicit component exceptions, so that its effect is predictable.
35. As a keyboard-only user, I want Tab's completion, segment-navigation or action-traversal role advertised, so that it does not unexpectedly change or submit my answer.
36. As a keyboard-only user, I want printable characters to remain text while editing, so that suggestions or navigation shortcuts do not steal ordinary input.
37. As a keyboard-only user, I want invalid submissions to preserve my draft and give actionable textual guidance, so that correction never requires retyping the entire answer.
38. As a keyboard-only user, I want oversized insertion or paste rejected as a unit rather than truncated silently, so that I know the exact candidate being edited.
39. As a keyboard-only user, I want pending or stale asynchronous validation not to accept an unverified answer, so that a late response cannot submit obsolete input.
40. As a keyboard-only user, I want Escape to leave the current transient layer before cancelling at the root, so that dismissing suggestions or capture does not accidentally abandon everything.
41. As a keyboard-only user, I want Ctrl+C to interrupt the whole prompt without accepting an answer, so that interruption remains consistent whether it arrives as input or process control.
42. As a keyboard-only user, I want terminal state restored before control returns, including after cancellation, interruption, EOF and recoverable failure, so that my shell remains usable.
43. As a keyboard-only user, I want repeated prompts in one process to behave consistently, so that cleanup defects do not accumulate between invocations.

### Linear interaction and screen-reader users

44. As a linear-interaction user, I want the same task outcomes as rich interaction, so that I am not offered a reduced answer model merely because its gestures differ.
45. As a linear-interaction user, I want questions, entered answers, errors and final outcomes to remain reviewable, so that I can recover context without interpreting a changing screen position.
46. As a linear-interaction user, I want a discoverable cancellation action besides Ctrl+C, so that cancellation does not require raw terminal key handling.
47. As a linear-interaction user, I want exact whole-line `/help` and `/cancel` commands, so that only explicitly advertised actions are interpreted as commands.
48. As a linear-interaction user, I want case-sensitive command matching without trimming, abbreviations or prefix matching, so that intended data does not unexpectedly cancel or request help.
49. As a linear-interaction user, I want ordinary slash-prefixed values and slash-separated dates treated as data, so that path and date entry does not depend on a command shortcut.
50. As a linear-interaction user, I want narrow backslash quoting for command collisions and leading backslashes, so that every literal answer remains representable.
51. As a linear-interaction user, I want quoting to occur at a well-defined submission boundary, so that editing an escaped default cannot accidentally turn its display escape into answer data.
52. As a linear-interaction user, I want caller-supplied answers, secret editing and explicitly identified paste to remain literal, so that no command or quoting rule changes their contents.
53. As a linear-interaction user, I want pasted newlines not to replay navigation or submission commands, so that a paste cannot trigger unintended actions.
54. As a linear-interaction user, I want unframed paste limitations stated rather than detection invented, so that the component does not promise a distinction the terminal did not supply.
55. As a screen-reader user, I want prompt purpose, accepted form, constraints and available actions stated in text, so that I do not need to infer them from color, indentation or symbols.
56. As a screen-reader user, I want current value, focused choice, selected state and accepted result to be distinguishable, so that exploration does not look like commitment.
57. As a screen-reader user, I want unavailable choices to remain discoverable with reasons, so that I can understand why an action cannot be selected.
58. As a screen-reader user, I want errors and outcomes retained rather than disappearing with a redraw, so that I can review what happened.
59. As a screen-reader user, I want rich interaction to avoid unnecessary whole-prompt repetition, so that updates remain comprehensible instead of repeatedly announcing stale instructions.
60. As a screen-reader user, I want meaningful bounded status updates with task identity, so that long operations are neither silent nor overwhelming.
61. As a screen-reader user, I want nonanimated rich output with explicit static state, so that removing animation does not force a different layout or hide status.
62. As a screen-reader user, I want hidden secret entry not to echo or replay secret values or lengths, so that completion, correction and cancellation do not disclose them.
63. As a screen-reader user, I want accessibility claims based on actual NVDA task completion, so that ANSI support or a visually correct screenshot is not represented as usability.
64. As an accessibility reviewer, I want an early feasibility probe before the whole suite is built, so that a failing shared editor or output model can be redesigned without widespread rework.
65. As an accessibility reviewer, I want qualification limited to the actual terminal, reader, versions, settings, modes and profiles tested, so that untested combinations are never implied to work.

### Text, secrets, multiline, suggestions and tags

66. As a person answering TextInput, I want entered text preserved unless its component documents a transformation, so that spaces and spelling are not silently normalized.
67. As a person answering TextInput, I want Enter to submit the current value and optional empty input to remain distinct from cancellation or default restoration, so that I control the answer.
68. As a person entering a Password, I want no visible echo by default, so that the secret is not exposed through ordinary terminal output.
69. As a person entering a Password, I want masking and secret prefill only by explicit configuration, so that length disclosure and retained-secret risks are deliberate.
70. As a person entering a Password, I want Enter to reach separate Submit, Edit, Clear, Help and Cancel actions, so that the hidden-value boundary is explicit and the secret is never previewed.
71. As a person entering a Password, I want failed validation and editing to preserve the secret without replaying it in messages, history or diagnostics, so that correction does not create disclosure.
72. As a person entering Multiline text, I want Enter to insert a newline and a visible Finish action to submit, so that multiline entry does not depend on Alt/Ctrl+Enter.
73. As a person entering Multiline text, I want linear `/list`, `/edit`, `/insert`, `/remove` and `/done` actions, so that I can review and correct existing content instead of only appending.
74. As a person entering Multiline text, I want logical lines returned with LF while preserving blank and intentional final blank lines, so that line structure survives across platforms.
75. As a person using Autocomplete, I want suggestions to assist valid free-form text rather than restrict it, so that unmatched valid answers remain possible.
76. As a person using Autocomplete, I want candidate acceptance separate from final submission, so that inspecting or accepting a suggestion cannot execute an unintended answer.
77. As a person using Autocomplete, I want linear numbered candidates and explicit submit/edit actions, so that the flow does not depend on a live popup.
78. As a person using TagInput, I want exactly kebab-case or snake-case normalization configured by the application, so that tag output uses one declared canonical style.
79. As a person using TagInput, I want word-aware Unicode-preserving normalization with no raw or arbitrary-normalizer option, so that tags such as `HTTPServer` and `Déjà Vu` are predictable.
80. As a person using TagInput, I want rich canonical previews, linear normalized-addition reports and duplicate detection on normalized values, so that I can see collisions before submission.
81. As a person using TagInput, I want Enter to add a valid draft and explicit finish/removal actions, so that tags are not silently discarded and empty Enter does not accidentally finish.
82. As a person using TagInput, I want Backspace to focus the last tag before explicit removal, so that correction cannot erase a tag unexpectedly.

### Choice, search, hierarchy and ordering users

83. As a person making a choice, I want navigation to remain provisional until explicit acceptance, so that browsing cannot change application state.
84. As a person using Select or Radio, I want arrows to navigate and Enter to accept the focused enabled item, so that one-choice prompts use a simple explicit gesture.
85. As a person making a choice, I want initial focus to prefer the configured default, then the first enabled choice, then the first available choice, so that Enter has predictable meaning.
86. As a person making a choice, I want unavailable defaults and removed choices to remain explained rather than silently replaced, so that an invalid configuration cannot select another answer for me.
87. As a person answering Confirm, I want No to be the default unless explicitly configured otherwise, so that an accidental submission is not implicitly affirmative.
88. As a person answering Confirm, I want rich Yes/No shortcuts to change only the draft and Enter to submit, so that one stray keystroke does not finish the prompt.
89. As a person using Checkbox or Toggle, I want one boolean with explicit checked/on or unchecked/off state and separate submission, so that presentation does not imply an immediate application change.
90. As a person using MultiSelect, I want Space to toggle without submitting and Enter or linear `/done` to validate/submit, so that membership changes remain under my control.
91. As a person using MultiSelect, I want filtering to preserve hidden selections with total/hidden counts and complete review, so that changing search does not silently discard work.
92. As a person using MultiSelect, I want selected results in original option order, so that output does not depend on toggle history or scroll/filter state.
93. As a person using MultiSelect, I want empty selection allowed by default and explicit minimum/maximum rules, so that an empty set is not confused with cancellation or invalid only by assumption.
94. As a person using MultiSelect, I want bulk actions scoped to enabled choices in the full filtered result set, so that Select visible and Clear visible never change unrelated hidden selections.
95. As a person using SearchSelect, CommandPalette or TimezoneSelect, I want explicit query and result focus with substring matching in source order by default, so that filtering is predictable and typing Enter cannot unexpectedly select a match.
96. As a person using search results, I want to return to the still-valid matching/default or prior focused result where appropriate, so that re-entry does not unexpectedly change the candidate.
97. As a person using CommandPalette, I want an explicitly accepted command identity returned rather than executed, so that navigation and preview never run commands.
98. As a person using TreeSelect, I want branch expansion/traversal separate from choosing one explicitly selectable node, so that opening a branch never chooses it or its descendants implicitly.
99. As a person using TreeSelect, I want rich parent/child navigation and linear open/up/choose actions with full path and expanded/selectable state, so that hierarchy remains understandable nonvisually.
100. As a person using SortableSelect, I want to reorder the complete list without changing membership, so that order and selection remain separate tasks.
101. As a person using SortableSelect, I want an explicit pick-up/drop move mode and linear move actions, so that reordering never requires modified arrows.
102. As a person using SortableSelect, I want locked anchors to stay fixed and prevent crossing, so that no move silently rearranges a protected item.
103. As a person using lists, I want stable item references distinct from current position, so that filtering, paging or reordering cannot make an old reference target another item.
104. As a person using TimezoneSelect, I want a canonical zone identity with dataset/version and reference-instant context, so that a displayed UTC offset is not mistaken for timezone meaning.

### Specialized value users

105. As a person using Slider or RangeSlider, I want exact typed entry and arrow adjustment constrained by declared bounds and steps, so that values are never silently rounded.
106. As a person using RangeSlider, I want stable Lower/Upper endpoint identities that never swap and stop at each other or the configured gap, so that crossing cannot change which endpoint I am editing.
107. As a person using TimeInput, I want time-of-day entry with explicit precision and 24-hour default, so that no date, timezone or instant is inferred.
108. As a person using TimeInput, I want labeled segments whose adjustments stop at boundaries, so that no hidden carry, wrapping or midnight rollover changes the value.
109. As a person using PathInput, I want native literal path syntax and absolute resolution against a displayed stable base, so that shell-like characters are not expanded unexpectedly and process working directory is unchanged.
110. As a person using FilePicker or DirectoryPicker, I want to choose an existing file or directory without filesystem mutation, so that browsing cannot create, delete, rename, overwrite or open content on the application's behalf.
111. As a person using filesystem pickers, I want separate Open and Choose actions, direct path entry, refresh and explicit hidden/link handling, so that navigation and selection are not overloaded.
112. As a person using filesystem pickers, I want symlinked-directory traversal only by explicit opt-in with cycle/error handling, so that links do not become an assumed traversal or sandbox mechanism.
113. As a person capturing a Keypress or KeyChordInput sequence, I want logical keys and observable modifiers rather than a physical-key or global-hotkey claim, so that the result reflects what the terminal could actually report.
114. As a person capturing keys, I want explicit capture followed by review/submission and no timing-based completion, so that an observed key cannot immediately become an accepted binding.
115. As a person declaring a key sequence, I want observed/declared provenance preserved per gesture, so that textual declaration never counts as verified capture.
116. As a person capturing keys, I want Escape and Ctrl+C to retain cancellation/interruption behavior, so that the component never traps me in binding entry.
117. As a person using an editor with a command-colliding default, I want a reversible explicit display representation whose escape cannot leak into my answer through editing or paste, so that literal data stays correct.

### Structured value users

118. As a person using NumberInput, I want integer mode by default and explicit decimal mode, so that finite base-10 entry does not inherit hexadecimal, exponent or special-value syntax from a general parser.
119. As a person using NumberInput, I want effective system noncurrency separators, grouping, signs and native digits honored, so that my regional numeric preferences apply rather than only my language name.
120. As a person using NumberInput, I want strict correct grouping and per-number digit consistency, so that malformed or mixed conventions are never guessed into a different number.
121. As a person using NumberInput, I want exact decimal bounds and precision without silent rounding, so that entered values do not lose meaning to binary floating-point conversion.
122. As a person using NumberInput when system conventions are unsupported, I want an explicit supported override and stable per-prompt interpretation, so that no ASCII/US fallback or preference change silently reinterprets my draft.
123. As a person using PortInput, I want ASCII decimal ports 1–65535 by default and zero only by explicit automatic-allocation opt-in, so that a reserved/bind-request value is not confused with an ordinary service port.
124. As a person using IPAddressInput, I want strict IPv4/IPv6 address parsing without hostname resolution, so that syntax validation does not imply reachability.
125. As a person using IPAddressInput in CIDR mode, I want address-with-prefix semantics preserving host bits, so that the component never silently replaces my address with its network.
126. As a person using scoped IPv6, I want explicit opt-in and separate zone preservation, so that local interface context is neither discarded nor claimed globally portable.
127. As a person using URLInput, I want an absolute URL under an explicitly allowed strict scheme profile, so that relative text, missing schemes or malformed repairs are not silently accepted.
128. As a person using URLInput, I want embedded user information rejected and accepted spelling preserved, so that credentials do not leak through previews and serialization does not change path/query meaning.
129. As a person using internationalized URL hosts, I want declared versioned UTS #46 nontransitional/IDNA interpretation with separate Unicode/ASCII display, so that Punycode conversion alone does not define acceptance.
130. As a person using EmailInput, I want one modern bare transport address with quoted local parts/address literals and preserved local-part case, so that display-name/header/list syntax is not confused with the address.
131. As a person using EmailInput, I want internationalized domains supported and Unicode local parts enabled only by explicit SMTPUTF8 opt-in, so that downstream requirements are visible and no deliverability is claimed.
132. As a person using ColorInput, I want declared sRGB hex/RGB/HSL/static-name formats with alpha supported by default, so that transparency remains a real value rather than absence.
133. As a person using ColorInput, I want supported precision and source expression preserved, with approximate swatches/rounded hex clearly labeled, so that previews never silently quantize the answer.
134. As a person using ColorInput, I want textual value and validation independent of the swatch, so that I need not perceive colors to enter or verify them.

135. As a person entering a slash-separated DateInput, I want automatic effective system date conventions with prominent labels and explicit overrides, so that field order is not guessed as year-first or another fixed order.
136. As a person entering DateInput, I want the locale's calendar including supported non-Gregorian calendars honored, so that a calendar year is never silently reinterpreted as Gregorian.
137. As a person entering DateInput, I want explicit era and leap/intercalary month context where required, so that three numeric fields do not erase necessary identity.
138. As a person entering DateInput, I want an exact disclosed system century window for short years, so that two-digit interpretation never depends on a hidden moving cutoff.
139. As a person entering DateInput, I want ASCII plus resolved native digits with consistency within each numeric field, so that digit policy is explicit without unnecessary whole-date uniformity.
140. As a person entering DateInput, I want slash and Tab to navigate complete segments without submitting and adjustments to stop at segment limits, so that navigation does not carry into another field.
141. As a person editing DateInput, I want dependent fields preserved when a change creates an invalid date, so that no day clamp, era replacement or leap-month substitution occurs silently.
142. As a person accepting DateInput, I want explicit review of the interpreted calendar date and separately labeled canonical ISO civil date before submission, so that the actual date is visible and editable.
143. As a person accepting DateInput, I want a date-only result retaining calendar/variant, field identities and conversion provenance, so that no invented midnight or timezone changes its meaning.
144. As a person using an unsupported system date convention, I want a clear limitation and explicit supported override, so that no Gregorian/order fallback silently changes the interaction.

### Mask, duration, cron and feedback users

145. As a person using MaskedInput, I want fixed or explicitly named adaptive templates with editable-slot and literal rules, so that formatting is understood and not mistaken for secrecy.
146. As a person using MaskedInput, I want automatic adaptive selection only for a unique fitting candidate, so that multiple valid interpretations require my explicit choice rather than configuration-order guessing.
147. As a person using MaskedInput, I want stable overwrite-slot editing, grapheme-aware navigation and distinct raw/formatted/template values, so that deletion does not shift other data and re-editing preserves meaning.
148. As a person pasting into MaskedInput, I want raw/formatted decoding accepted only when unambiguous, so that stripping punctuation cannot silently alter the answer.
149. As a person using DurationInput, I want explicitly selected elapsed or calendar-relative modes with case-sensitive human unit tokens, so that minutes, months and fixed/calendar semantics cannot be confused.
150. As a person using DurationInput, I want portable ASCII amounts, nonnegative default, optional one-global-sign mode, duplicate-unit rejection and exact microsecond conversion, so that quantities are never truncated or overflowed silently.
151. As a person entering a calendar period, I want to retain an unapplied period with whole calendar components and elapsed sub-day components, so that months/years are not reduced to fixed seconds without application context.
152. As a person using CronInput, I want an explicitly selected Cronie-style five-field or Quartz profile, so that field positions, day rules and special tokens are never guessed from field count.
153. As a person using CronInput, I want expression collection separate from commands, directives, registration and execution, so that accepting a schedule never performs application work.
154. As a person using CronInput preview, I want an explicit zone/provider, reference instant, result count, search horizon and work budget, so that sparse schedules cannot cause unbounded searching.
155. As a person using CronInput preview, I want nonexistent matching local times skipped and both repeated-time instants included under a declared civil-time matching model, so that no exact scheduler-emulation promise is invented.
156. As a person using CronInput preview, I want no-match-in-horizon, exhausted-budget, unsupported-range and provider-error outcomes distinguished, so that a bounded search is not reported as a schedule that can never run.

157. As a person reading Text feedback, I want supplied strings rendered literally with readable semantic labels, so that unsafe controls cannot alter my terminal and meaning does not depend on color.
158. As a person watching Progress, I want start, meaningful milestones and final outcome rather than animation frames or unchanged heartbeats, so that long operations remain informative without transcript flooding.
159. As a person watching determinate Progress, I want unknown totals represented explicitly and invalid updates rejected, so that no fabricated percentage or clamped value misleads me.
160. As a person watching Spinner, I want animation supplementary to textual state and no fabricated percentages for unknown work, so that nonanimated output remains meaningful.
161. As a person watching MultiSpinner, I want named stable task identities, group-wide bounded intermediate updates, retained failures and a complete final summary, so that concurrent work never collapses into blanket success.
162. As an application author, I want Text, Progress, Spinner and MultiSpinner to remain feedback-only, so that they never acquire input, own cancellation or change my operation.

### Maintainers and reviewers

163. As a maintainer, I want automated tests at the public component prompt/presentation boundary, so that they verify accepted results, typed outcomes and external behavior instead of private state.
164. As a maintainer, I want one shared scripted terminal-session seam for the component suite, so that tests do not introduce separate private hooks per component.
165. As a maintainer, I want deterministic tests for stale async responses, paste provenance, validation and focus, so that races and identity mistakes cannot become intermittent behavior.
166. As a maintainer, I want native integration checks for console state, input handling and restoration, so that synthetic decoding cannot falsely certify terminal lifecycle behavior.
167. As a maintainer, I want exact provider/source conformance cases for calendars, numbers, paths, networks, colors, masks, durations and cron, so that a permissive parser cannot redefine the contract.
168. As a maintainer, I want the first qualification to cover all 38 components in plain-rich and linear modes, so that a few successful components cannot become a misleading whole-library accessibility claim.
169. As a maintainer, I want later manual regression scoped to affected interactions plus release smoke checks, with broad changes triggering full reruns, so that evidence stays relevant to the tested revision.
170. As a maintainer, I want exact version/settings/revision manifests and sanitized evidence retained, so that support boundaries remain reproducible without recording real secrets.
171. As a maintainer, I want cross-platform implementation and automated engineering checks on Windows, macOS and Linux as infrastructure allows, while keeping the user's manual scope to Windows Terminal + NVDA, so that implementation coverage does not become an unassigned manual testing burden.
172. As a maintainer, I want failed early feasibility or qualification tasks to block rollout/claims and reopen the relevant decision, so that no implementation deadline silently weakens accessibility or value-meaning requirements.

## Implementation Decisions

### Component and value model

- Public components, including feedback components, are classes. Construction is separate from explicit prompt/presentation invocation.
- Positional component parameters are allowed. Records group coherent data and settings; do not create per-component option-holder classes.
- Prefer named record fields when field purpose is not obvious from position. Do not introduce large anonymous positional tuples as a substitute for a meaningful grouped contract.
- Invariant-bearing record groups are extension types with a private parsing path. Components accept the validated grouped type, not an unchecked raw record or an invalid value silently repaired at invocation.
- Configuration errors belong to creation/validation; user-input errors belong to the prompt's correction flow.
- Construction does not acquire input, change terminal state or render. Prompt/presentation invocation owns terminal lifecycle.
- Each invocation starts a fresh session and does not replay an earlier accepted answer. One component instance does not conduct concurrent sessions.
- Multi-field accepted answers may be records. Success, cancellation, interruption, input-ended and unavailable are named outcome variants, not a nullable-field record or a boolean/no-answer shortcut.
- Exact component signatures, record fields, method names and outcome-type names are implementation design. The construction/modeling boundary is fixed by this spec.
- Implement against the resolved component contracts, not by inventing a class for every atlas color/layout variant. Theme, structure and component are separate concerns.

### Modes, streams and session lifecycle

- Every interactive component has rich and linear task equivalents. Feedback components provide stable textual output rather than artificial interactive variants.
- Before prompting, mode precedence is current explicit user choice, saved user preference, application preference, then automatic selection. Applications must respect stronger user choices.
- Automatic selection uses actual required interactive input/output capabilities; it is not screen-reader detection. A terminal flag or ANSI-support property alone is not sufficient.
- Explicitly requested rich mode fails clearly before prompting if required capabilities are unavailable. Never silently downgrade it.
- Linear interaction remains sequential and reviewable. It does not mean noninteractive, and it does not permit a pending-default workaround where actual editable initial values are required.
- Actual editable initial values are mandatory in both modes. If the selected editor/backend/stream arrangement cannot provide them, report unavailable. Plain line reads or printing a default do not establish prefill.
- Command-aware editors track literal answer data separately from display encoding. Pasted literal ranges retain provenance. Decode/recognize once on logical submission where permitted, rather than reparsing intermediate editor state.
- Prompt and feedback output defaults to stderr. Applications may explicitly select streams. Standard output remains application-owned.
- Check input and each output stream independently. Redirected prompt output uses stable text without cursor addressing or animation.
- Redirected/missing interactive input requires explicit supplied answers or an opted-in line-input source. Never implicitly consume a pipe, open a controlling terminal or accept a default because no interaction is available.
- EOF produces a distinct input-ended outcome. It does not submit partial data, execute an unterminated command or become cancellation/default acceptance.
- Restore terminal state before returning control after submission, cancellation, interruption, EOF and recoverable errors. Verify repeated sessions and competing-reader avoidance. Forced process termination is outside the cleanup guarantee.
- The component returns outcomes; the application owns process exit and all accepted-answer side effects.

### Editing, commands and validation

- Preserve text by default: no universal trimming, case-folding or Unicode normalization. Component policies such as Multiline LF and TagInput normalization are explicit exceptions.
- Character-wise navigation/deletion and user-facing character limits use extended grapheme clusters. Display-column width and byte/protocol/resource limits are separate constraints.
- Essential editor actions use terminal-delivered arrows, Backspace/Delete and line-boundary keys with alternatives when unavailable. Word movement, selection and clipboard accelerators are optional and capability-specific.
- Oversized insertion/paste is rejected as a unit without silent truncation. If native editing already captured the candidate, retain it for correction but block submission.
- Enter normally validates/submits. Component-specific newline, tag-addition, suggestion-acceptance, directory-navigation and key-capture exceptions are advertised. Tab's completion/internal-traversal/action role is likewise explicit.
- Printable characters remain text during editing. Identified paste is literal data and requires explicit submission; pasted newlines are not replayed as actions. Without framing, identical typed/pasted input may be indistinguishable.
- Linear commands are exact case-sensitive whole-line `/help` and `/cancel`, plus explicitly advertised component extensions. Matching occurs after removing only the line terminator and before trimming/normalization/component parsing.
- A backslash quotes an immediately following exact active command or another leading backslash. Other backslashes are preserved; the result is literal data and is never reparsed as a command. Document Windows rooted/UNC examples.
- Caller-supplied answers and hidden secret editing bypass command recognition and quoting. Identified pasted literal data cannot become a command on later submission.
- `/help` lists active commands and quoting without mutating the pending answer or revealing secrets. `/cancel` cancels the whole standalone linear prompt without accepting an answer.
- Rich Escape dismisses a transient layer before root cancellation; Ctrl+C interrupts the whole prompt from any layer, including process-control delivery. Neither accepts an answer.
- Invalid submission retains the draft and produces persistent textual correction guidance. Optional live feedback does not repeatedly announce the same error. Pending/stale asynchronous validation cannot accept an unverified answer.
- Local parsing/constraints are the default. Network/environment checks require explicit caller opt-in, visible pending/error states and bounded/cancellable behavior. Syntax does not prove availability, reachability, deliverability or ownership.
- Required/optional state is explicit. Optional empty input means no value, not zero, transparency, a default or cancellation. An explicit empty value is different from absence only where a component contract says so.

### Component-specific semantics

- Apply the detailed contracts in the resolved map tickets. Do not replace them with parser defaults or visual atlas hints. The following are cross-component boundaries, not a substitute for the ticket-level acceptance rules.
- TextInput preserves text; Password defaults to no visible echo and uses an explicit secret-safe post-edit action stage. Masking and secret prefill are explicit options.
- Multiline has portable finish/edit actions and LF logical-line results. Autocomplete permits independently valid free-form text and separates candidate acceptance from submission. TagInput offers only application-configured kebab/snake normalization with canonical duplicate checks.
- Checkbox and Toggle each yield one boolean; Radio and Select each yield one choice. Choice changes stay draft-only until explicit acceptance. Confirm defaults visibly to No unless configured otherwise.
- Disabled choices remain discoverable with reasons but cannot be selected. Lists stop at boundaries by default. Stable identities/references never change meaning through filtering, paging or reordering.
- Single-choice initial focus uses configured default, then first enabled choice, then first available choice; unavailable focus warns and cannot submit. Result re-entry preserves a still-valid matching/default or prior focus as appropriate without silently substituting another item.
- MultiSelect preserves hidden selections, applies explicit visible-result bulk scopes and count constraints, and returns canonical source order. SearchSelect and CommandPalette default to substring matching/source order with separate query/result focus. CommandPalette returns a command identity and never executes it.
- TreeSelect chooses one explicitly selectable node, separating expansion from selection. SortableSelect returns a permutation of the full list through explicit move actions and respects locked anchors. TimezoneSelect returns canonical zone identity with data/reference context.
- Slider and RangeSlider enforce step/bounds for typed and adjusted values without rounding. Range endpoints never swap. TimeInput is time-of-day only, with labeled bounded segments and no carry/rollover.
- PathInput returns an absolute path against a displayed stable base without changing working directory or applying implicit shell expansion. FilePicker/DirectoryPicker select existing items without mutation. Linked-directory traversal is explicit opt-in with cycle/error handling and no implied sandbox.
- Keypress/KeyChordInput use logical keys/observable modifiers and explicit capture/review. KeyChordInput is an ordered gesture sequence with explicit completion. Preserve observed/declared provenance per gesture. Cancellation keys remain reserved; textual declaration never proves future delivery or conflict freedom.
- NumberInput defaults to integer, has explicit decimal mode, honors effective system noncurrency conventions and exact decimal interpretation. Strict grouping/digit/sign rules, stable snapshots and explicit override prevent ambiguous fallback.
- PortInput uses ASCII decimal 1–65535 by default and explicit zero semantics. IPAddressInput supports IPv4/IPv6, explicit CIDR preserving host bits and explicit scoped IPv6. URLInput uses strict allowed-scheme profiles, no userinfo, no silent repairs and preserved accepted spelling. EmailInput uses one bare transport address, internationalized domains and explicit SMTPUTF8 local parts. ColorInput uses bounded sRGB forms, supports alpha and preserves precision with labeled approximate previews.
- DateInput is slash-based and follows qualified effective system conventions, including genuine supported non-Gregorian calendars. Explicit era/month identity, exact disclosed short-year windows and per-field digit consistency preserve meaning. Preserve invalid drafts; require review and a date-only result with canonical civil identity and retained calendar/conversion meaning. Never invent midnight or silently substitute Gregorian.
- MaskedInput supports fixed/adaptive templates, explicit ambiguity resolution, stable-slot overwrite editing and distinct raw/formatted/template meaning. Format masks do not hide secrets.
- DurationInput supports explicitly selected elapsed and calendar-relative modes with human unit tokens, portable ASCII amounts, optional global sign and exact microsecond conversion. Calendar-relative mode collects an unapplied period; it does not apply or total calendar units.
- CronInput supports explicitly selected Cronie-style five-field and Quartz profiles. Expressions are not commands or job registration. Optional previews require explicit context and finite limits, use declared civil-time matching rather than scheduler emulation, and distinguish bounded-search failure meanings.
- Text, Progress, Spinner and MultiSpinner are feedback-only. They do not take input/focus or own cancellation. Use safe literal text, meaningful bounded textual updates, explicit outcomes, nonanimated rich state and named concurrent-task summaries. Provisional linear numeric defaults are 10-percentage-point milestones with at most one intermediate numeric update per five seconds, coalescing to the latest value; MultiSpinner has at most one intermediate batch per five seconds across the group. Start/outcome/failure messages do not wait for intermediate timers.
- Unknown progress totals never invent percentages; disposal or 100% does not imply success; stale asynchronous updates cannot overwrite final outcomes.

### Backend and provider selection

- Select and inspect exact backend/editor/parser/calendar/provider implementations before relying on them. Package documentation, current/latest pages and historical prototype success are not sufficient behavioral evidence.
- The existing Dart TUI direction remains a candidate. The archived Windows patch and Input/Select/MultiSelect trials are narrow historical evidence, not a current backend adoption or accessibility guarantee.
- Verify any Windows raw-mode restoration fix by exact source comparison and native original/final state regression. Do not remove the local-patch requirement based solely on a related upstream issue or changelog.
- Editable linear defaults require a real editor mechanism. Plain Dart/POSIX cooked line input is insufficient. Candidate native/application-managed editors must pass stream, grapheme, paste, cancellation, restoration and NVDA probes before qualification.
- Calendar support must identify calendar variant, provider/data version, range, era/month identity and strict round-trip conversion. Non-Gregorian support cannot be implemented as Gregorian parsing with relabeled fields.
- Cron syntax/matching does not establish scheduler execution behavior. Do not introduce job registration, scheduling side effects or exact daemon-emulation claims.

## Testing Decisions

### External-behavior seam

- Test every component through its public class construction and explicit prompt/presentation invocation, not private state or component-specific test hooks.
- Use one shared scripted terminal-session seam to supply input/paste/termination/resize events and capture external output/results. It must preserve event provenance, logical answer outcomes and observable state transitions needed by the contracts.
- A good test performs a user task and asserts the accepted answer, distinct outcome, externally visible instructions/state/error/output and restoration effects. It does not inspect internal buffers, private focus variables, implementation-only caches or renderer call sequences.
- Prefer end-to-end component tests at that shared public seam. Test validated record extension types through their public creation/validation boundary rather than manufacturing invalid internals.
- Test rich and linear modes independently. Test configuration/capability rejection before interaction separately from user-input validation.
- Unit tests for parsers/providers are supplementary. A successful general-purpose parse is not a component conformance test. Visual snapshot tests are supplementary and never accessibility proof.
- Do not treat this shared seam as evidence that a particular terminal, OS or screen reader works. It is deterministic behavioral verification, not an accessibility guarantee.

### Required behavior coverage

- Cover all 38 in-scope components, their explicit construction, ordinary task completion, applicable validation/correction and cancellation/interruption/EOF outcomes.
- Include actual editable initial values, deletion to empty, literal/default command collisions, leading backslashes, editing with identified paste and representation-escape preservation.
- Cover grapheme editing/limits separately from wide/combining/emoji display behavior; actual clipboard paste separately from protocol injection; framed and unframed paste limitations.
- Cover invalid drafts, oversized insertion/paste, empty/optional values, stale async validation/suggestions, repeated prompts and capability-unavailable failures.
- Cover boundary navigation, disabled reasons, invalid/removed defaults, stable item identity/reference, hidden selection counts, filtered bulk scope, result order and focus re-entry.
- Cover tree branch selection, sorting locked anchors, key observed/declared provenance, repeats, reserved cancellation and no command execution from palette navigation.
- Cover exact number grouping/digits/signs/precision, ports/IP/CIDR/scopes, URL scheme/userinfo/IDNA/spelling, bare email/SMTPUTF8/octet limits, sRGB alpha/precision/approximation, and strict DateInput calendar/era/leap/month/short-year/round-trip behavior.
- Cover mask adaptive ambiguity/raw-versus-formatted paste, duration elapsed/calendar distinction and exact precision, cron dialect/day/DST/bounded-search cases, and feedback coalescing/finalization/stale updates.
- Include narrow terminal/resize, monochrome/ASCII, nonanimated rich, stable redirected output, independent stream redirection, explicit noninteractive policy and partial EOF.
- Pin implementation/provider versions for conformance fixtures. Keep standard-specific conformance cases distinct from NVDA task results.

### Native integration and lifecycle

- Use real native integration checks for input acquisition, process interruption, console/terminal state and cleanup. Preserve exact Windows original/final console-mode and cursor checks across submission, Escape, Ctrl+C, EOF, recoverable error and repeated sessions.
- Use the actual selected backend revision, stream ownership and protocol modes. Verify no concurrent competing input readers and no cursor-addressed/animated output in redirected streams.
- Add platform-specific automated engineering checks on Windows, macOS and Linux runners as execution infrastructure is available. Unrun checks remain explicitly unverified. Do not assign manual OS-compatibility testing to the user.
- Actual OS clipboard, terminal/host, SSH/multiplexer, native editor, IME/layout and Unicode-width behavior require real environment checks before claiming support for those combinations.
- Filesystem acceptance must use controlled existing paths, link/reparse variants, permissions, refresh races and no-mutation checks; it must not claim race-free later file access or sandbox security.

### Feasibility and accessibility gates

- Before bulk component implementation, run small Windows Terminal + NVDA probes in plain-rich and linear modes. Cover actual editable defaults, labels/current state, correction, secret-safe editing, bounded status and safe cancellation/restoration.
- If a foundational probe fails, stop rollout and reopen the affected design/backend decision. Do not weaken the contract to make the current candidate pass.
- The user's manual testing scope is Windows Terminal + NVDA only. Narrator and manual macOS/Linux compatibility tests are not required of them.
- Include experienced NVDA usability review. A sighted visual pass, hearing any speech or completing a scripted decoder test does not prove nonvisual task completion.
- The initial public accessibility claim is whole-library only: all 38 components in the `plain` rich profile and linear mode, including applicable no-color/nonanimated behavior, in the exact qualified Windows Terminal/NVDA environment.
- Record actual OS/terminal/shell/NVDA versions/settings, layout/IME, locale, dimensions/protocols, application/backend/provider revisions and modes. Preserve sanitized expected/observed results and limitations; never raw secrets.
- An unsupported configuration may be reported unavailable only when outside the qualified baseline. It cannot waive a promised baseline behavior. A required failed/incomplete task blocks the claim.
- After initial qualification, use impact-based manual reruns plus release smoke checks; broad input/rendering/backend changes can trigger the full suite. Do not extend the claim automatically to other rich structures, terminals/readers, OSes or provider configurations.

### Existing evidence and test prior art

- The current package and test suite are an initial Dart scaffold; they provide no component behavior seam to preserve.
- The archived prototype contains historical real Windows-console Input/Select/MultiSelect trials, restoration checks, decoder tests and protocol-injected paste tests on locally patched Dart TUI 3.0.0.
- That archive is prior art for native lifecycle and input scenarios, not proof that a current backend, the 38 components, macOS/Linux or NVDA have passed.
- The research reports provide standards/platform references and proposed probes, not executed results. Retain the evidence categories rather than presenting research as tests.

## Out of Scope

- `StepperForm`, multi-prompt form orchestration and general form composition.
- `RegexInput` as a component and regex-based input validation for this effort.
- Built-in anchored calendar-period arithmetic, calendar-period endpoint/total previews and ISO-style duration profiles. DurationInput collects the unapplied period; the caller owns its application.
- Month-grid calendar navigation or a `/` command that opens a calendar. DateInput remains slash-based with explicit calendar context.
- OS-global hotkey registration, arbitrary physical-key capture and claims that every logical gesture is deliverable on every terminal.
- Command execution, scheduling/registration, socket binding, network validation, email deliverability/ownership verification and other application side effects as prompt behavior.
- Filesystem creation, deletion, renaming, overwrite or content opening by pickers; save-as/new-directory interaction and implicit filesystem sandbox guarantees.
- Shell command execution, implicit shell expansion or generic shell escaping as a replacement for the component's literal path/input contract.
- Contextual/system colors, calculations, relative-color syntax and wider color spaces beyond the declared initial sRGB subset.
- A universal all-terminal, all-calendar, all-provider or all-screen-reader support claim. Qualification remains exact and evidence-bound.
- Automatic whole-library claims for untested layouts, terminals/readers, OSes or provider configurations.
- Package/repository identifier renaming as part of this component-interaction specification. Trelis is the project name; the scaffold's existing package identifier still requires separate deliberate release work.
- Shipping an unverified upstream/local Windows backend fix or removing an existing restoration safeguard without exact source and native regression evidence.

## Further Notes

- The completed [Wayfinder map](map.md) and its resolved tickets are the canonical interaction-decision authority. This spec is the implementation handoff; it does not replace ticket-level detail.
- The [visible handoff summary](../../doc/trelis-interaction-handoff.md) orients implementation order and scope. The [research index](../../doc/research/index.md) links all eight source reports with their original exact commits/branches.
- The [domain glossary](../../GLOSSARY.md) defines rich/linear interaction, feedback components, command/literal entry, draft/focus state, civil dates, calendar periods, canonical tags, logical key gestures and related project vocabulary.
- The atlas remains a visual reference: 40 historical specimens, 45 themes and 15 structures. The current implementation scope is 38 components. One named `plain` rich profile is the initial accessibility-qualification target, alongside linear mode; this does not eliminate implementation of other structures.
- Broad terminal compatibility remains a design goal, not a support claim. Cross-platform implementation is required even where actual OS/accessibility verification remains outstanding.
- No components, dependencies, terminal probes or accessibility qualification have been implemented by this planning/specification work. Missing execution must remain visible in future handoff evidence.
