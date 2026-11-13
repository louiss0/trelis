# Ticket 24 — formatted-value migration evidence

**Status:** pass for the scripted public formatted-value seam, including the
follow-up shared-writer routing fix. The backend evidence gate remains pending
and is owned by its dedicated ticket.

## Source and environment

- **Implementation revisions:** `ecb043b` (`feat: complete formatted value migration`)
  and `1afacd8` (`fix: serialize formatted-value preview writes`, the follow-up
  that routes live preview writes through the session's serialized writer).
- **Branch:** `ticket/backend-24-formatted-values`. The migration was merged to
  integration as `6368698`; the follow-up is based on integration tip `9a2bcbf`
  (which normalises wrapped prose comparisons) and is not merged.
- **Date:** 2026-11-13
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable.
- **Input/output:** synthetic `Stream<String>` input and `StringBuffer` output,
  a public `TerminalSession.run` scope for the shared-session scenarios, a
  recording `TerminalIo` adapter for the standalone terminal scenario, and a
  declared failing `StringSink` for the writer-failure scenario.
- **Profiles:** an explicitly declared rich profile (cursor support, indexed-256
  colour depth, 100×30 geometry) and `PromptMode.linear`. No real terminal,
  environment variable or font is consulted. The palette scenario supplies a
  distinguishable `ColorThemes.terminalDefault` override with indexed foreground
  colour 12.

## Public behavior exercised

`test/formatted_values_migration_test.dart` invokes only `NumberInput`,
`PortInput`, `IPAddressInput`, `EmailInput`, `ColorInput` and `DurationInput`
through their public constructors and `prompt`, and verifies:

- each input opens with a compact active-format cue and no syntax dump, while
  `Ctrl+T` (rich) and `/help` (linear) carry the detailed format, the component
  limitations and the caller's `supplementaryHelp`, without replacing the shared
  editing help;
- every `InstructionDisplay` policy changes only the editing guidance: the cue
  and component help remain reachable under `hidden`, `compact` and `expanded`;
- rich interaction keeps the same cue and component help, and dismissal leaves
  the draft editable before the accepted answer;
- cancellation, interruption, input-ended and invalid supplied answers remain
  distinct `Cancelled`, `Interrupted`, `InputEnded` and `Unavailable` outcomes
  for all six inputs, and an invalid interactive draft is re-prompted with the
  component's own validation message before the corrected answer is accepted;
- one shared linear session and one shared rich session run all six inputs over a
  single session-owned reader/writer, including in-session help, and the colour
  preview, duration interpretation and email domain interpretation land in the
  session output rather than merely on `stderr`;
- a preview write that fails on the selected output propagates the original
  writer failure, retires the session before the scope ends, blocks a late
  feedback-region update and refuses another attached prompt, and never copies
  the private writer diagnostic (a canary in its message) into output;
- the email domain interpretation follows the selected `TerminalIo` output for a
  standalone terminal invocation, alongside the existing source/output routing;
- an attached prompt rejects competing invocation configuration
  (`mode` on an attached `PortInput`) with `ArgumentError`;
- distinguishable configuration is forwarded: `allowZero`, `cidr`/`scoped`,
  `smtpUtf8`, explicit numeric convention/decimal/precision (`required: false`
  keeps a nullable numeric answer), `required`, `durationMode` and `signed`
  each change the accepted value or the rejection;
- a declared palette reaches every component's opening, and truthful limitation
  copy stays visible: port availability, address reachability and zone
  dependence, email deliverability and transport address literals, approximate
  colour hex, and unapplied calendar duration components.

Deliberate visible changes in the migration revision: `DurationInput`'s opening
sentence is now a compact mode cue (the previous opening repeated the whole
grammar), its live interpretation writes to the shared session output, and its
component help retains the exact-microsecond and maximum-magnitude rules.
`README.md` documents the compact cue/help split, the `instructions`,
`supplementaryHelp` and `ColorTheme` options, and the shared
`terminal`/`outputProfile`/`session` invocation arguments for these six inputs.

The follow-up fixes a real contract defect rather than adding evidence. The
colour preview (`color_input.dart`), duration interpretation (`duration_input.dart`)
and email domain interpretation (`url_email_input.dart`) selected
`session._output` directly, bypassing `_writeShared`. That violated the
single-serialized-writer and failure-retirement contracts: a failed selected
output during a preview did not retire the session, so a later live-region or
prompt write could still reach the failed writer. The session branch now uses
the existing private `_SessionOutputSink`, which performs every write through
`_writeShared`; the standalone `ScriptedInput`, `output:` and `terminal:` routes
are unchanged. The email interpretation additionally follows `terminal.output`,
matching the other two inputs. No shared editor behavior changed.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/color_input.dart lib/src/duration_input.dart lib/src/url_email_input.dart test/formatted_values_migration_test.dart` | Passed: 4 files checked, 0 changed |
| `dart test test/formatted_values_migration_test.dart test/number_input_test.dart test/network_input_test.dart test/email_input_test.dart test/color_input_test.dart test/duration_input_test.dart test/terminal_session_failure_recovery_test.dart test/terminal_session_feedback_test.dart test/terminal_io_test.dart --reporter expanded` | Passed: 84 tests |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: 152 relative links in 45 Markdown files |
| `dart test --reporter compact` | Passed: 748 tests |

Mutation and red/green checks: the suite detects a removed active-format cue
(`PortInput is missing its cue`); before the migration fix it detected both the
verbose duration opening and the duration interpretation written outside the
shared session output; and before the follow-up fix each of the three preview
scenarios failed with `late updates must not reach a failed writer` (and the
email terminal scenario with `the interpretation must use the selected terminal
output`).

## Limitations

This record is deterministic scripted public-behavior evidence at the listed
implementation revision. It is not native PTY, visible-terminal, screen-reader,
resize/short-screen, modal-help, fault-injection, Linux/macOS CI or final
backend-gate evidence; those remain owned by their dedicated tickets and the
final evidence gate. It covers no component outside the six listed inputs and
makes no whole-library accessibility claim.

Two further limitations are recorded rather than waived:

- The shared-writer failure scenario is deterministic scripted injection into
  the selected sink for these three preview paths only. It does not exercise
  native write failures, a failure while a modal help owns the screen, or the
  fallback where cleanup also fails; those belong to the session-failure ticket.
  Standalone `source`, `output:` and `terminal:` routing is asserted for the
  email interpretation and preserved by construction, but not re-proved for
  every component by a failure scenario.
- A repository-wide `dart format --output=none --set-exit-if-changed .` still
  reports three files from earlier tickets (`test/linear_text_input_events_test.dart`,
  `test/native_text_input_capabilities_test.dart`,
  `test/terminal_session_short_screen_test.dart`). They are untouched by this
  ticket and the failure is identical at the merged integration revision.
