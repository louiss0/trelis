# 07 Linear interaction parity and suite migration

Status: resolved

**Blocked by:** [01](01-field-cell-model-and-validation.md)

**Resolution notes (ticket 07):**

- Verified the linear contract end-to-end and fixed three linear-path gaps in `CronInput._run` / the delegated `TextInput._run` path: (a) `/help` without a configured preview now emits the cron dialect help (`_submitHelp`: field shape, syntax, acceptance and preview notes) instead of generic text-input help, and the executed `/help` command is cleared from the draft (`clearHelpCommand`) matching the preview path; (b) `/cancel` tracking during an active linear preview only accumulates printable characters, so arrow keys, escape sequences and paste payloads can no longer corrupt the command line and hang the prompt; (c) the preview entry editor passes `exemptCommandsFromLimit` in linear mode for parity with the shared text contract. Internal-only change: `TextInput._run` gained optional `helpText`/`linearHelpText`/`clearHelpCommand` parameters; no public API signatures changed.
- Screen-reader presentation already resolves to linear with concise essential context (`'<label> <profile> cron expression entry.'` + compact hint) emitted before the prompt by `ThemeFormattedPrompt.cron`; covered by new tests.
- New suite `test/cron_linear_parity_test.dart` (14 tests) covers: single-line unix entry, quartz 6- and 7-field verbatim acceptance, linear/rich acceptance parity, `/help` guidance + draft clearing, invalid-draft retention and correction in both preview and no-preview paths, backslash command quoting, identified paste as literal entry, `/cancel`, review `/preview` `/edit` `/submit` round-trips, unknown-review-input guidance, `/cancel` during preview surviving intervening control keys, and screen-reader essential-before presentation with the linear command set.
- `dart analyze` clean; all cron suites, text-input/help suites and the 15 theme acceptance matrices pass.

**Rich-mode suites still assuming single-line entry — migrate during the post-ticket-02 integration pass** (the field-cell rich editor does not exist on this base, so these intentionally still drive the current single-line rich editor and were left unchanged):

- `test/component_acceptance_matrix_test.dart` — `CronInput / rich: review schedule` scripts `'* * * * *\r\t\r\t\r'`.
- All 15 `test/<name>_theme_acceptance_matrix_test.dart` — `CronInput / rich: review schedule` scripts `'* * * * *\r\t\r\t\r'`.
- `test/theme_structure_framing_test.dart` — `_Case('CronInput', richAnswer: '* * * * *\r\t\r\t\r')` (RailTheme/BranchTheme runners).
- `test/theme_enclosure_framing_test.dart`, `test/theme_form_ledger_colon_framing_test.dart`, `test/theme_heading_framing_test.dart` — `_Case('CronInput', richAnswer: '* * * * *\r\t\r\t\r')`.
- `test/theme_formatted_components_test.dart` — `_textBackedFixtures` `CronInput` rich variant `\x14\x1b* * * * *\r` (Ctrl+T help + single-line submit).
- `test/cron_input_test.dart` — `rich review navigates preview then submit actions` types the whole expression then Tabs through review.
- `test/cron_interaction_conformance_test.dart` — `rich preview cancellation retains review before root cancellation` scripts `'0 0 31 2 *\r\t\r'`.
- `test/cron_workflow_migration_test.dart` — every rich scripted run assumes single-line entry: `'* * * * *\r\t\r\t\r'` (declared-facts, attached-session, shared-session, edit-stage, outcome and guidance tests), typed `'* * * * *'` + `\r\t\r\t\r` (idle-resize repaint), and `'* * *\x14\x1b\x03'` / `'* * * * *\r\t\x14\x1b\x03'` help tests.

**What to build:** Preserve and verify the linear/screen-reader contract for the new field-cell `CronInput`. Linear interaction continues to accept the complete space-separated cron expression on a single command-aware entry line (`/help`, `/cancel`, backslash command quoting, identified paste as literal entry, `/preview`, `/edit`, `/submit` during review), validating against the same 5-field unix and 6-or-7-field quartz rules via the ticket-01 model — invalid drafts retained for correction. Screen-reader presentation resolves to linear with concise essential context presented before the prompt. Update existing compatibility and structural-theme acceptance-matrix suites whose scripted rich-mode inputs assumed single-line cron entry so they drive the new field-cell `Tab` workflow cleanly (see spec Testing Decisions: prior art suites to follow). See the [spec](../spec.md) Implementation Decisions: preview stage/cancellation layers and linear interaction; user stories 29 and testing bullet on suite migration.

## Acceptance criteria

- [ ] Linear mode accepts full expressions with identical validation outcomes to rich mode, retains invalid drafts, and supports the documented command set including review-stage commands.
- [ ] Screen-reader/linear presentation emits concise essential context before the prompt.
- [ ] Existing cron conformance/workflow/matrix suites are updated to the field-cell workflow and pass; no public API signatures change.
- [ ] Tests assert parity of accepted `CronExpression`/`CronPreview` results across modes through the public seam.

## Answer

Linear/screen-reader parity verified and three linear-path gaps fixed; rich-mode suite migration deliberately deferred to the post-ticket-02 integration pass (see Resolution notes above for the exact list).

- `lib/src/cron_input.dart`: the no-preview delegated path now passes cron dialect help (`_submitHelp`, with `_acceptanceNote`/`_unconfiguredPreviewNote` counterparts to the review-stage wording) plus `clearHelpCommand: true` into `TextInput._run`; the preview entry editor passes `exemptCommandsFromLimit: linear`; the linear `/cancel`-during-preview tracker only accumulates printable single characters so control keys, escape sequences and paste payloads reset it instead of hanging the prompt.
- `lib/src/text_input.dart`: private `TextInput._run` gained optional `helpText`, `linearHelpText` and `clearHelpCommand` parameters forwarded to `_edit`; defaults preserve prior behavior for every other caller. No public API signatures changed.
- `test/cron_linear_parity_test.dart`: 14 tests covering the story-29 contract — single-line unix entry, quartz 6/7-field verbatim acceptance, linear/rich acceptance parity through `CronInput.prompt`, `/help` cron guidance with command clearing, invalid-draft retention and correction with and without a configured preview, backslash command quoting, identified paste as literal entry, `/cancel`, review `/preview` `/edit` `/submit`, unknown-review-input guidance, `/cancel` during an active preview surviving intervening control keys, and screen-reader essential-before presentation (`ThemeFormattedPrompt.cron` + `InteractionPreferences(screenReader: on)`) with the linear command set.
- Verified: `dart pub get`, `dart analyze` clean, `dart test` green on all cron suites, the text-input/help suites and all 15 theme acceptance matrices.
