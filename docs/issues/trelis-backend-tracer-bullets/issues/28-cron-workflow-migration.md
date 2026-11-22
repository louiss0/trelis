# 28: Migrate CronInput entry, preview and review

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Enter and review a cron expression with explicit preview actions on the shared backend.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-HELP](../../trelis-backend-implementation/spec.md#b-help), [B-EVENT](../../trelis-backend-implementation/spec.md#b-event).

- [x] Preserve declared profile, limits, preview configuration, interpretation and accepted CronExpression contract.
- [x] Retain expression/edit/preview/submit stages without adding unsupported syntax or scheduler guarantees.
- [x] Provide syntax/workflow help, active context and preview limitations with correct compact actions.
- [x] Preserve source/profile/session forwarding and all explicit outcomes.
- [x] Exercise actual public rich/linear workflows, preview errors and background updates deterministically.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Merged into integration as `c5cad27`. Retained the existing shared component-help-plus-exact-commands dispatch; no shared-editor code changed in the merge. Post-merge: 796 full-suite tests passed, 71 cron tests, 22 session/failure/large-step tests and 144 component-matrix tests passed; analysis, changed-Dart formatting and doc links passed. Native/GUI/cross-platform gates remain pending.

## Answer

Implemented on `ticket/backend-28-cron-workflow-migration` in commits `1dea842`
(output-profile resolution and shared sessions), `3cac7dc` (stage-led help and
wrapped guidance), `b427110` (background updates, resize and outcomes),
`dd9511a` (README), `43e0592` (mode-consistent help wording), `1d0030d`,
`0aabb48` and `0f45d7f` (evidence), based on integration `9d6ecbe`. Merging the
latest integration tip into the branch was a no-op ("Already up to date"); that
tip was unchanged when this report was written, and ticket 17's shared-writer
failure handling is intact — the migration suite asserts that a failed shared
writer still surfaces the original failure, retires the session and rejects a
late registration. Merging this branch into integration is deliberately left to
the parent.

`CronInput` now accepts `terminal`, `outputProfile` and `session`. It resolves
the invocation/source/legacy output-profile precedence, constrains the profile
to observed geometry, applies `NO_COLOR` through it, refuses an explicitly
requested rich mode the effective profile cannot support, and selects rich only
in `automatic` mode when the profile permits rich interaction. An attached
prompt inherits its session's input, output, mode and profile, reads the
session-owned key stream, repaints through the session writer, and rejects
competing invocation configuration. Without a configured preview the entry and
review stages remain the shared text contract: the existing `TextInput` flow is
reused with the same profile/key/session arguments instead of being restated, so
the no-preview result, validation messages and `CronExpression` mapping are
unchanged.

The workflow stages are unchanged: expression entry, validation with the
retained draft, then review with Edit, Preview and Submit in rich mode and
`/edit`, `/preview`, `/submit`, `/help`, `/cancel` in linear mode. No syntax was
added and no scheduler guarantee was introduced; help and the preview report
state explicitly that a bounded matching preview is not scheduler execution.
The accepted `CronExpression` keeps its exact spelling and declared profile,
including for a stamped `SuppliedAnswer`.

Both stages now lead their own component help. `Help: Entering the expression
for the unix profile, five fields: …` and `Help: Reviewing the retained
expression …` keep the dialect field shape, the 4096 UTF-16-code-unit limit, the
accepted syntax (Quartz `L`, `LW`, `L-n`, `nW`, `#`, weekday `L`, bounded year),
the zone/horizon/count/budget/timeout interpretation and the
not-a-scheduler limitation in one block; rich help names Edit, Preview and
Submit, while the focused action stays announced on the editor line, and linear
`/help` keeps the exact command, quoting and identified-paste rules. Compact
hints now name the help route. Guidance, validation and preview reports are
measured against the declared geometry, and a rich notice takes over the
editable line instead of being appended to the field the user just left.
Matching instants are reported as unbroken data lines. An idle resize repaints
the retained draft inside the new observed width without changing or accepting
it.

Verification on Windows 11 Home (`10.0.26200`) with Dart SDK 3.13.2
(`windows_x64`): `dart format --output=none --set-exit-if-changed` on the five
changed source/test files reported `Formatted 5 files (0 changed)`; `dart
analyze` reported no issues; the new `test/cron_workflow_migration_test.dart`
(13 tests) plus the existing cron suites passed 71 tests, the isolate probe
passed 1 test, and the component acceptance matrix passed 144 tests; `dart run
tool/check_doc_links.dart` checked 153 links in 43 files; and the full suite
passed 727 tests. Code and tests are at revision `43e0592`; the final pass was
repeated at the branch tip, which changes only this record's wording. Evidence,
source revision, environment, commands, expected/actual results and limitations
are recorded in
`assets/evidence/trelis-backend/28-cron-workflow-migration.md`.

Limitations: this is scripted public-behavior evidence only. Native PTY,
Linux/macOS CI, visible-terminal GUI/NVDA, the native `cron_input_windows.ps1`
harness, alternate-screen modal help for this family and the final evidence gate
remain outstanding. Wrapping splits at display cells rather than word
boundaries (and matching instants are emitted unwrapped, so a width below 24
columns cannot show one inside the declared geometry), guidance written before
an idle resize is not re-wrapped, the resize observer's notifications stream must
support repeated listens, a lone trailing Escape reports `InputEnded` (pre-
existing shared key-parser behaviour), these prompts still have no `ColorTheme`
or `InstructionDisplay` argument, the review help block cannot restate the
focused action because shared help text is fixed per editor lifetime, and three
unrelated test files already failed the repository-wide format check on the
integration tip. One shared line changed in `lib/src/text_input.dart` (a flow
that supplies `linearHelpText` now keeps it when it also advertises exact
commands; flows without it are unchanged), which overlaps the region ticket 26
restructured, so merging both branches needs a deliberate resolution there.
