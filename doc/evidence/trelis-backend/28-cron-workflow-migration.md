# Ticket 28 — CronInput entry, preview and review migration

**Status:** pass for the scripted public cron prompt seam.

## Source and environment

- **Implementation revision:** `43e0592`. It follows `1dea842` (profile
  resolution and shared sessions), `3cac7dc` (stage-led help and wrapped
  guidance), `b427110` (background updates, resize, outcomes), `dd9511a`
  (README) and `43e0592` (mode-consistent help wording); the evidence record
  itself is the commit that contains this file. Every command in the table
  below was re-run at `43e0592`.
- **Branch:** `ticket/backend-28-cron-workflow-migration`, based on integration
  `9d6ecbe` (`Merge branch 'ticket/backend-17-failure-recovery'`). The
  integration tip was merged into this branch before this report was written.
- **Date:** 2026-11-13.
- **Environment:** Windows 11 Home (`10.0.26200`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`, commands run in the ticket worktree
  `prompty-backend-ticket-28`.
- **Input/output:** synthetic scripted string streams and `StringBuffer`
  output, plus public `TerminalSession.run`, `Spinner`, `ScriptedInput`,
  `OutputProfile`, `TerminalResizeObserver`, `TerminalIo` and typed
  `PromptResult` observations.
- **Profiles:** explicitly declared rich 40×8 and 80×24 profiles with cursor
  support and no colour, one 20×6 narrow ASCII profile, and a 14×5 idle resize
  observation. No geometry is read from the host terminal and no test depends
  on the developer's locale, clock zone or environment.

## Public behavior exercised

`test/cron_workflow_migration_test.dart` (13 tests) drives only public
constructors and `prompt`, and records that:

- `CronInput` resolves the invocation/source/legacy output-profile precedence:
  an explicit rich profile is honoured even when the legacy rich hint is false,
  an explicitly requested rich mode without declared cursor support and
  positive geometry is `Unavailable`, and `automatic` mode falls back to the
  linear workflow without rich facts;
- an explicit `TerminalIo` adapter is acquired and restored exactly once, and
  `NO_COLOR` reaches the resolved profile (this family emits no owned colour
  spans yet);
- an attached prompt inherits session input, output, mode and profile, rejects
  competing invocation configuration with `ArgumentError`, and refuses a second
  concurrent prompt;
- both stages lead their own help: `Help: Entering the expression for the unix
  profile, five fields: …` and `Help: Reviewing the retained expression …` keep
  the dialect field shape, the 4096 UTF-16-code-unit limit, the accepted
  syntax (including Quartz `L`, `LW`, `L-n`, `nW`, `#` and weekday `L`), and the
  bounded-preview limitation in one block; rich help names Edit, Preview and
  Submit, while the focused action stays announced on the editor line;
- linear entry and review help keep the exact command workflow (`/preview`,
  `/edit`, `/submit`, `/help`, `/cancel`), the quoting rule and the
  identified-paste rule; dismissing help restores the draft, and a stray
  Ctrl+T in the linear workflow shows the linear wording rather than the rich
  action guidance;
- guidance, validation and preview reports are measured against the declared
  geometry: at 20 columns every rich physical line stays inside the declared
  width, and the linear opening guidance re-wraps inside it while preserving
  the `Enter an expression, then /preview` active cue;
- a preview round at a new idle geometry repaints the retained draft line
  inside the observed width without changing or accepting it, and the
  observation subscription is released when the prompt exits;
- `CronInput` runs inside `TerminalSession.run` with a `Spinner`; two
  background updates are written through the session writer while the review
  editor is active, each followed by a repaint of the retained review editor,
  and the retained expression is still the accepted answer;
- a failed shared writer surfaces the original failure from the attached
  prompt, retires the session, and rejects a late `Spinner` registration, so
  ticket 17 behaviour is preserved for this family;
- the Edit stage retains the expression and re-reviews it in both modes: rich
  `Edit` returns to entry with the draft and announces the review twice,
  linear `/edit` returns to entry with `Current text: * * * * *` before
  `/submit` accepts it;
- every explicit outcome is preserved in both modes — `Accepted`, `Cancelled`
  (rich `Escape`, linear `/cancel`), `Interrupted` (Ctrl+C), `InputEnded`
  (entry EOF and review EOF) and `Unavailable` (unsupported source, invalid
  supplied answer) — and an accepted `CronExpression` keeps its exact spelling
  and declared profile, including for a stamped `SuppliedAnswer`.

The pre-existing cron suites continue to cover validation and the accepted
contract: `test/cron_input_test.dart` (22 tests: profile/spelling, preview
bounds, gaps/folds, status distinctions), `test/cron_interaction_conformance_test.dart`
(7 tests: preview interruption/cancellation, retained review, invalid drafts,
EOF), `test/cron_profile_conformance_test.dart` (13 tests: dialect
conformance, hostile fields, bounded range, provider isolation),
`test/cron_provider_bounds_test.dart` (5 tests: provider error/timeout,
configuration equality) and `test/cron_large_step_test.dart` (1 test: the
isolate probe). Rich cases in those suites now declare a synthetic rich
profile, per the shared profile contract; `test/cron_input_console_app.dart`
and the Windows `cron_input_windows.ps1` harness were left unchanged because
the native path already supplies an observed profile, and the harness markers
(`Enter an expression, then /preview`, `Review: <expression>`,
`Calculating preview;`, `Matching preview: <status>`) are unchanged.

Implementation notes:

- `CronInput.prompt` accepts `terminal`, `outputProfile` and `session`; an
  attached prompt goes through `TerminalSession._promptRunner` and inherits
  session input, output, mode and profile. Without a configured preview the
  entry and review stages are the shared text contract, so the existing
  `TextInput` flow is reused with the same profile/key/session arguments
  instead of being restated.
- The preview workflow resolves
  `OutputProfile.resolve(invocation:, source:, supportsRich:)`, constrains it
  with `_constrainToObservedGeometry`, applies `NO_COLOR` through that profile,
  refuses an explicitly requested rich mode the profile cannot support, and
  selects rich only for `automatic` when the profile permits rich interaction.
- Guidance uses `_writeWrappedText` at `_textInputWidth(effectiveProfile)`; a
  notice in rich mode first takes over the editable line with the same
  carriage-return/erase sequence the editor uses, so guidance never overwrites
  the field the user just left. Reported matching instants are data and are
  never split.
- One shared `_edit` change (`lib/src/text_input.dart`): a flow that supplies
  stage-specific linear help keeps it when it also advertises exact commands.
  Previously the command list silently replaced component help. Flows without
  `linearHelpText` are unchanged.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/cron_input.dart lib/src/text_input.dart test/cron_workflow_migration_test.dart test/cron_input_test.dart test/cron_interaction_conformance_test.dart` | Passed: `Formatted 5 files (0 changed)`. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test test/cron_workflow_migration_test.dart test/cron_input_test.dart test/cron_interaction_conformance_test.dart test/cron_profile_conformance_test.dart test/cron_provider_bounds_test.dart --reporter compact` | Passed: 71 tests. |
| `dart test test/cron_large_step_test.dart --reporter compact` | Passed: 1 test. |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | Passed: 144 tests. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 153 relative links in 43 Markdown files.` |
| `dart test --reporter compact` | Passed: 727 tests. |

The repository-wide `dart format --output=none --set-exit-if-changed .` still
reports three files changed (`test/linear_text_input_events_test.dart`,
`test/native_text_input_capabilities_test.dart`,
`test/terminal_session_short_screen_test.dart`). Those files are unmodified by
this ticket and already failed that check on integration `9d6ecbe` with this
SDK, so the ticket records the failure instead of reformatting unrelated files.

## Limitations

This is deterministic scripted public-behavior evidence. It is not native
terminal or PTY evidence, not visible-terminal GUI or NVDA evidence, and not
Linux/macOS CI evidence; those remain owned by tickets 31, 32 and the final
evidence gate. No human usability or whole-library accessibility claim is made.

- **Native console harness not re-run:** `test/cron_input_windows.ps1` and
  `test/cron_input_console_app.dart` were not executed here. The opening
  statement is now two guidance lines instead of one long line, so the harness
  marker survives at narrower console widths than before, but that is a
  source-level observation, not native evidence.
- **Wrapping shape:** `_writeWrappedText` wraps by display cell rather than
  word boundary, so a word, a zone identifier or an ISO instant inside a
  notice can be split across physical lines. Matching instants themselves are
  emitted as unwrapped data lines, so a width below 24 columns cannot show an
  instant inside the declared geometry.
- **Help cannot follow the focused action:** the review help block names all
  three actions and states that the focused action is announced after every
  change, because the shared editor's help text is fixed for one editor
  lifetime. The focused action remains visible only on the
  `Review action: <name>.` line.
- **Rich vertical overflow** is only observable as transcript scrollback; these
  tests assert physical line widths and retained drafts, not a scrolled live
  viewport.
- **Resize is repaint-only for the editable line:** guidance written before an
  idle resize is not re-wrapped, matching the shared `TextInput` opening
  behaviour at this revision. The editor line does re-wrap inside the new
  observed width.
- **Resize notification contract:** the cron editors subscribe once per nested
  editor, so the observer's `notifications` stream must support repeated
  listens (a broadcast stream, as used by the evidence fixtures).
- **Lone trailing Escape:** a scripted stream that ends with a bare `ESC`
  reports `InputEnded` because the escape disambiguation timer is cancelled
  when the stream closes, so the rich cancellation evidence sends `ESC`
  followed by another byte. This is pre-existing shared key-parser behaviour.
- **Modal help on an alternate screen** is not exercised for this family: the
  rich fixtures declare cursor support but not alternate-screen support, so the
  evidence covers the transcript help fallback only.
- **No `ColorTheme` parameter:** this prompt still has no colour argument and
  emits no owned colour spans; `NO_COLOR` only constrains the resolved profile.
- **No `InstructionDisplay` parameter:** instruction-presentation overrides
  remain `TextInput`-only, so this family always shows the compact hint and the
  help route.
- **Shared `_edit` help change:** the one-line preference for
  `linearHelpText` overlaps the same region that the range/mask migration
  (ticket 26) restructured, so merging both branches needs a deliberate
  resolution in `lib/src/text_input.dart`.
