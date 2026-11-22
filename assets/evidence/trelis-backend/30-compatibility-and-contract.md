# Ticket 30 — compatibility, contract step and public-behavior evidence

**Status:** pass for the scripted public compatibility, help and contract seams
described below. This report is a record of executed checks at the stated
revision; it does not open the backend evidence gate, does not implement
structural themes, and makes no whole-library accessibility claim.

## Source and environment

- **Branch:** `ticket/backend-30-compatibility-contract`, worktree
  `../prompty-backend-ticket-30`.
- **Base:** `integration/trelis-backend-tracer-bullets` at `13b524b`, after the
  `27`, `17`, `22` and `23` migrations were confirmed ancestors of the
  integration tip.
- **Implementation revision:** `c3e03ee` (public-surface contraction,
  Autocomplete identity repair, compatibility inventory, help gap closure and
  the three format-only test repairs). `577fcf3` adds only this report and the
  README/CHANGELOG migration guidance, and changes no production code or test.
  Every command below was last re-run on `577fcf3`; `83bb622` and any later
  commits on this branch update this report's revision metadata only.
- **Date:** 2026-11-13.
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable (`dart --version`).
- **Selected input/output:** synthetic `Stream<String>` input with
  `StringBuffer` output, explicitly declared rich profiles (cursor support plus
  positive 100x30 or 80x24 geometry) for rich scenarios, `SuppliedAnswer` for
  literal checks, and one `TerminalSession` scenario per migrated family.
- **Geometry/width policy:** default `TextDisplayMap` width policy under the
  declared profile; colour is undeclared in the transcript scenarios, so no
  escape sequences are emitted there.

## What this ticket changed

1. **Contract step on the public surface.** `lib/prompty.dart` no longer
   re-exports `DisplayText` or the five query/results types
   (`QueryResultRow`, `QueryResultsIdentityModel`, `QueryResultsNotice`,
   `QueryResultsPhase`, `QueryResultsPresentation`). Ticket 23 added that export
   so its own suites could name the projection, which made an internal
   presentation contract constructible by consumers. The projection stays
   observable through the public `TextInputTranscript`; presentation tests now
   import the narrow internal contract (`package:prompty/src/presentation.dart`)
   the same way `test/presentation_safety_test.dart` already did.
   `test/public_compatibility_inventory_test.dart` guards the export list, so a
   future export is an explicit API decision instead of an accident.
2. **Response-local candidate identity.** `Autocomplete` linear interaction
   recorded the accepted suggestion's response-local ordinal in
   `TextInputPresentationEvent.reference`, which is documented as the
   *displayed source-stable reference*. A position is not a choice identity
   (theming decision 06: never reinterpret candidate positions as stable source
   identities), so the reference slot is now empty for a response-local
   acceptance; the candidate text is recorded and the ordinal stays a
   `QueryResultRow.position` in the presented response. Source-stable families
   (`SearchSelect`, `CommandPalette`, `TimezoneSelect`, `TreeSelect`,
   `SortableSelect`) keep recording references. Red-then-green:
   `meaningful presentation events a response-local candidate acceptance has no
   source-stable reference` failed with `Actual: <1>` before the change.
3. **Help coverage gaps closed, no behavior change.** `URLInput` and
   `TimezoneSelect` had component help but no test asserting it.
   `test/url_input_test.dart` now covers URL-specific `Ctrl+T` help in rich and
   linear interaction (asserting the help text is URL-specific and that a hidden
   draft canary never appears) and documents that a typed `/help` line is
   literal answer data for a hidden draft. `test/timezone_select_test.dart` now
   covers the timezone stage help (identifier/city/alias matching, canonical
   identity, no offset or current time consulted) in both modes and keeps help
   access reachable under `InstructionDisplay.hidden`.
4. **Format-only repairs.** `dart format --output=none --set-exit-if-changed .`
   reported three unformatted files inherited from earlier tickets
   (`test/linear_text_input_events_test.dart`,
   `test/native_text_input_capabilities_test.dart`,
   `test/terminal_session_short_screen_test.dart`). They are formatted here with
   no assertion, input or behavior change (the diff is line breaking and
   trailing commas only) so the required clean format gate can run; all three
   suites pass.

No golden or snapshot output was regenerated anywhere in this ticket.

## Compatibility inventory (B-COMPAT)

Baseline: `docs/issues/trelis-theming/api-baseline.md` (source revision
`80f4752`), revalidated against the revision above by reading the current
constructors and by compiling the inventory test. "Added" columns are the
intentional migrations the backend specification allows; every baseline
parameter keeps its position, type and default.

| Component | Answer type | Baseline constructor parameters | Added constructor parameters | Invocation additions |
| --- | --- | --- | --- | --- |
| `TextInput` | `String` | label, initialValue, required, validate, maxLength | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `Password` | `String` | label, initialValue, mask, required, validate | — | terminal, outputProfile, session |
| `Multiline` | `String` | label, initialValue, required, validate, maxLength | — | terminal, outputProfile, session |
| `Autocomplete` | `String` | label, suggestions, initialValue, required, validate, maxLength | instructions, supplementaryHelp | terminal, outputProfile, session |
| `TagInput` | `List<String>` | label, style, maxLength, validate | — | terminal, outputProfile, session |
| `Confirm` | `bool` | label, initialValue | colors | terminal, outputProfile, session |
| `Checkbox` | `bool` | label, initialValue | colors | terminal, outputProfile, session |
| `Toggle` | `bool` | label, initialValue | colors | terminal, outputProfile, session |
| `Select<T>` | `T` | label, choices, defaultValue | colors | terminal, outputProfile, session |
| `Radio<T>` | `T` | label, choices, defaultValue | colors | terminal, outputProfile, session |
| `MultiSelect<T>` | `List<T>` | label, choices, defaultValues, min, max | colors | terminal, outputProfile, session |
| `SearchSelect<T>` | `T` | label, choices, defaultValue, search | instructions, supplementaryHelp | terminal, outputProfile, session |
| `CommandPalette<T>` | `T` | label, commands, defaultValue, search | instructions, supplementaryHelp | terminal, outputProfile, session |
| `TimezoneSelect` | `String` | label, defaultValue, unavailable | instructions, supplementaryHelp | terminal, outputProfile, session |
| `TreeSelect<T>` | `T` | label, nodes, isCurrent, defaultValue | colors | terminal, outputProfile, session |
| `SortableSelect<T>` | `List<T>` | label, choices | colors | terminal, outputProfile, session |
| `Slider` | `String` | label, minimum, maximum, step, initialValue, precision, units | — | terminal, outputProfile, session |
| `RangeSlider` | `(String, String)` | label, minimum, maximum, step, minimumGap, initialLower, initialUpper, precision, units | — | terminal, outputProfile, session |
| `TimeInput` | `({int hour, int minute, int? second})` | label, twelveHour, seconds, initialValue | — | terminal, outputProfile, session |
| `PathInput` | `String` | label, base, initialValue, allowNonexistent, target | colors | terminal, outputProfile, session |
| `FilePicker` | `String` | label, base | colors | terminal, outputProfile, session |
| `DirectoryPicker` | `String` | label, base | colors | terminal, outputProfile, session |
| `Keypress` | `KeyGesture` | label, requireObservation | — | terminal, outputProfile, session |
| `KeyChordInput` | `List<KeyGesture>` | label, requireObservation | — | terminal, outputProfile, session |
| `NumberInput` | `NumericAnswer?` | label, convention, conventionProvider, decimal, minimum, maximum, precision, required | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `PortInput` | `int` | label, allowZero, initialValue | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `IPAddressInput` | `IPAddressValue` | label, cidr, scoped, initialValue | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `URLInput` | `String` | label, allowedSchemes | — | terminal, outputProfile, session |
| `EmailInput` | `String` | label, smtpUtf8, initialValue | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `ColorInput` | `ColorValue?` | label, required, initialValue | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `MaskedInput` | `MaskedValue` | label, templates, initialValue, interpretation | — | terminal, outputProfile, session |
| `DurationInput` | `DurationValue` | label, durationMode, signed, allowZero, minimumMicroseconds, initialValue | instructions, supplementaryHelp, colors | terminal, outputProfile, session |
| `DateInput` | `CivilDate` | label, order, calendar, digits, initialValue | — | terminal, outputProfile, session |
| `CronInput` | `CronExpression` | label, profile, initialValue, preview | — | terminal, outputProfile, session |
| `Text` | feedback | content, kind | — | present: terminal, session |
| `Progress` | feedback | label, total, interval, milestone | — | start: terminal, session |
| `Spinner` | feedback | label | — | start: terminal, session |
| `MultiSpinner` | feedback | tasks, interval | — | start: terminal, session |

Baseline invocation was `{source, mode, userPreference, applicationPreference,
output}` for the 34 interactive components and
`{output, mode, userPreference, applicationPreference, supportsRich}` for
`Progress`, `Spinner` and `MultiSpinner`; `Text.present` took `{output}`. The
additions above are the only public invocation changes.

`test/public_compatibility_inventory_test.dart` (8 tests) compiles the whole
inventory: 34 interactive and four feedback constructors with every baseline
parameter supplied a non-default value plus the added ones, the shared prompt
invocation bound for all 34, each answer type bound through
`PromptInvocation<T>` (including the `RangeSlider` record, the `TimeInput`
record, `NumericAnswer?` and `ColorValue?`), the generic selection types, and
the documented constructor defaults (`Password.mask`, `PortInput.allowZero`,
`IPAddressInput.cidr`, `ColorInput.required`, `NumberInput.required`,
`DateInput.calendar`/`digits`, `TimeInput.twelveHour`, `DurationInput.signed`/
`allowZero`, `PathInput.allowNonexistent`/`target`, `MaskedInput.interpretation`,
`TagInput.style`, boolean `initialValue`). Behavioural checks of the invocation
seam and the outcomes stay in the acceptance matrix and the per-family suites.

## Public behavior by component (B-PARITY)

Task, outcome and callback coverage is retained per component family, in both
modes, by the existing suites; this ticket re-ran them at the revision above.
`test/component_acceptance_matrix_test.dart` (144 tests) drives all 34
interactive components in rich and linear interaction through their own
construction-time defaults, rejects an overlapping prompt, recovers from a
stream error, and distinguishes `Cancelled`, `Interrupted` and `InputEnded`;
the four feedback components are covered in the same file for `Text`,
`Progress`, `Spinner` and `MultiSpinner` outcomes.

Family suites carrying the deeper callbacks/defaults/limits coverage:

| Family | Suites re-run |
| --- | --- |
| Text, password, multiline, tags | `text_input_test`, `password_test`, `multiline_test`, `tag_input_test`, `text_input_help_test`, `linear_text_input_events_test` |
| Booleans | `boolean_test` |
| Single/multi choice | `select_radio_test`, `multi_select_test` |
| Suggestions and search | `autocomplete_test`, `search_select_test`, `command_palette_test`, `timezone_select_test`, `async_search_migration_test` |
| Tree and order | `tree_select_test`, `sortable_select_test`, `tree_order_migration_test` |
| Formatted values | `number_input_test`, `formatted_values_migration_test` |
| Date and time | `date_input_*`, `time_input_test`, `date_time_migration_test` |
| Ranges and masks | `slider_test`, `masked_input_test`, `range_mask_migration_test` |
| Paths and browsers | `path_input_test`, `path_input_behavior_test`, `path_input_errors_test`, `filesystem_picker_test`, `filesystem_migration_test` |
| Key capture | `key_capture_test` |
| Cron | `cron_input_test`, `cron_workflow_migration_test` |
| Feedback | `feedback_test`, `multi_spinner_test`, `terminal_session_feedback_test` |
| Session/backend | `terminal_session_test`, `terminal_session_modal_help_test`, `terminal_session_short_screen_test`, `terminal_session_failure_recovery_test`, `idle_text_input_resize_test`, `output_profile_text_input_test` |

## Help and protected content (B-HELP)

Component help is component- and stage-specific in both interactions, and every
instruction policy keeps a help route and the protected content. Verified by
reading the help composition of each component and by the following executed
suites:

| Component(s) | Help coverage |
| --- | --- |
| `TextInput` | `text_input_help_test` iterates every `InstructionDisplay` policy, keeps context and the help route, and keeps the draft/caret through help; `linear_text_input_events_test` keeps repeated help occurrences distinct |
| `Password` | `password_test` keeps action-stage help separate from literal secret entry; evidence `18-private-entry-migration.md` |
| `Multiline`, `TagInput` | `multiline_tag_migration_test` (rich and linear stage help, help owns painting and restores state) |
| `Autocomplete`, `SearchSelect` | `autocomplete_test`, `search_select_test` (query/results/loading/failure/empty help, help dismissal restores draft and focus) |
| `CommandPalette` | `command_palette_test` (hidden instructions keep application guidance and the help route) |
| `TimezoneSelect` | `timezone_select_test` (added here: stage help states matching rules and canonical identity in both modes, reachable under hidden instructions) |
| `Confirm`, `Checkbox`, `Toggle` | `boolean_test` (kind-specific controls and linear defaults) |
| `Select`, `Radio` | `select_radio_test` (references, paging commands and unavailable reasons) |
| `MultiSelect` | `multi_select_test` (selection commands, bounds and reasons) |
| `TreeSelect`, `SortableSelect` | `tree_order_migration_test` (navigating/choosing/reference and ordering/movement stages) |
| `Slider`, `RangeSlider`, `MaskedInput` | `range_mask_migration_test`, `slider_test` (focused-control stages, bounds, gap, slots) |
| `NumberInput`, `PortInput`, `IPAddressInput`, `EmailInput`, `ColorInput`, `DurationInput` | `formatted_values_migration_test`, `number_input_test` (format cue and component help per fixture) |
| `DateInput`, `TimeInput` | `date_time_migration_test` (focused fields, review stage) |
| `PathInput`, `FilePicker`, `DirectoryPicker` | `filesystem_migration_test` (entry/browsing/literal-path/review help, caveats survive help) |
| `Keypress`, `KeyChordInput` | `key_capture_test` (help does not arm or steal a capture) |
| `URLInput` | `url_input_test` (added here: URL-specific `Ctrl+T` help in both modes with no draft disclosure; typed `/help` is literal data) |
| `CronInput` | `cron_workflow_migration_test` (entry and review help with the dialect limits) |
| `Text`, `Progress`, `Spinner`, `MultiSpinner` | Feedback components have no artificial interactive help by design; `13`/`14` evidence and `feedback_test` cover their presentation and lifecycle |

Protected content was checked per component rather than by sampling: warnings,
validation, unavailable reasons, review actions, caveats and format cues are
emitted outside optional guidance, and the suites above assert them surviving
help and dismissal. Secret and capture safeguards are unchanged:
`password_test`, `url_input_test` and `presentation_safety_test` cover hidden
drafts, masked length disclosure and safe encoding; `key_capture_test` covers
“help does not arm a capture”; `async_search_migration_test` and
`search_select_test` cover obsolete/closed-session rejection, deferred results
during help and shared-writer failure.

## Legacy retirement audit (contract step)

Caller audit result: **no separate legacy implementation remains to delete.**

- Tickets 02–29 migrated each component in place; there is no parallel legacy
  component library, no `lib/legacy` tree, no orphan library file (every
  `lib/src/*.dart` is imported by `text_input.dart`/`feedback.dart` or is a
  `part`), and `dart analyze` reports no unused elements.
- Every retained compatibility surface has live callers: `supportsRich` (lib:
  130 references, test: 77, example: 1), the `output:` `Stdout` parameter and
  `ScriptedInput` (lib 44 / test 61 / example 1), `terminal:` (44/40/0),
  `outputProfile:` (181/271/0) and `session:` (78/145/0). None is a dead path.
- The internal presentation scaffolding (`PresentationCompositor`,
  `PresentationDeclaration`, `TextInputPresentationContent`,
  `TextInputEditableRegion`) has no production caller yet and is exercised only
  by `test/presentation_safety_test.dart`. It is deliberately **kept**: the
  theming contract requires declaration-time omission diagnostics and the
  safety-area repair before structural themes can be declared. Deleting it
  would remove the only executed proof of protected-content repair, so it is
  not legacy.
- `assets/prototype-themes/` stays: it is a design specimen referenced by the
  theme research, not a runtime implementation with consumers.
- The one API *contraction* this step performs is the accidental public export
  of the internal projection described above.

## Executed verification

Run in `../prompty-backend-ticket-30` at the revision above, on Windows
NT 10.0.26200.0 with Dart SDK 3.13.2:

| Command | Result |
| --- | --- |
| `dart pub get` | Passed: `Changed 54 dependencies!` |
| `dart format --output=none --set-exit-if-changed .` | Passed: `Formatted 150 files (0 changed)` |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 155 relative links in 54 Markdown files.` |
| `dart test --reporter compact` | Passed: 923 tests |
| `dart test test/component_acceptance_matrix_test.dart` | Passed: 144 tests |
| `dart test test/async_search_migration_test.dart test/search_select_test.dart test/autocomplete_test.dart test/command_palette_test.dart test/timezone_select_test.dart test/password_test.dart test/url_input_test.dart test/key_capture_test.dart test/presentation_safety_test.dart test/public_compatibility_inventory_test.dart test/text_input_help_test.dart` | Passed: 178 tests |
| `dart test test/linear_text_input_events_test.dart test/native_text_input_capabilities_test.dart test/terminal_session_short_screen_test.dart` | Passed: 11 tests after the format-only repair |
| `git merge integration/trelis-backend-tracer-bullets` | `Already up to date.` — the integration tip was still `13b524b`, so the tested revision did not change |

The whole-suite count is 910 tests inherited from the integration tip plus 13
tests added here (one Autocomplete identity regression, eight compatibility
inventory checks, two URLInput help checks, two TimezoneSelect help checks). No
existing test was deleted or weakened, and no expected transcript was
regenerated.

## Limitations

- This is deterministic scripted public-behavior evidence. It is not native PTY,
  visible-terminal, screen-reader, Linux/macOS CI or final-gate evidence; those
  remain owned by tickets 31, 32 and the evidence gate. No whole-library
  accessibility claim is made, and this report does not open the backend gate
  or authorize the named-theme rollout.
- The whole-suite result is worktree-path dependent for two filesystem wrap
  assertions. In `../prompty-backend-ticket-30` the full suite passed 923 tests;
  the integration report of 908 passed plus two failed wrap assertions came from
  `../prompty-backend-ticket-27`, where the longer temporary path changes the
  wrapping under test. That is the same path-length-sensitive defect already
  recorded on ticket 27, with a queued repair (`a0fc708f`) owned by the merger;
  it is not duplicated here.
- Three test files were reformatted to make the repository format gate pass.
  The change is formatting only, verified by reading the diff, but it is a
  change to files owned by earlier tickets and is recorded rather than hidden.
- The public-surface guard reads `lib/prompty.dart` as source text. It detects an
  added or removed barrel export, not a namespace-level API proof; the compile
  checks in the same file cover the authoring surface that consumers actually
  use.
- A consumer can read a projection through `TextInputPresentationEvent.results`
  but cannot name its type from the package barrel. That is the intended
  boundary, and it is a source-level incompatibility for any downstream code
  that imported those types from ticket 23 (no such consumer exists in this
  repository; the two suites that did now import the internal seam).
- Rich presentation is written to the transcript rather than an alternate
  screen, so vertical overflow is ordinary scrollback and only horizontal
  wrapping at the declared width was exercised.
- Feedback components intentionally have no interactive help; that is a contract
  decision, not missing coverage.
- No named structural theme classes, colour palettes beyond
  `ColorThemes.terminalDefault`, or factory signatures were added; the theme
  rollout remains blocked behind the backend evidence gate.
