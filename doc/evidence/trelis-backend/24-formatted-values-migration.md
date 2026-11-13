# Ticket 24 — formatted-value migration evidence

**Status:** pass for the scripted public formatted-value seam. The backend evidence
gate remains pending and is owned by its dedicated ticket.

## Source and environment

- **Implementation revision:** `ecb043b` (`feat: complete formatted value migration`)
- **Branch:** `ticket/backend-24-formatted-values`, merged with
  `integration/trelis-backend-tracer-bullets` at `9d6ecbe` before this work.
- **Date:** 2026-11-13
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable.
- **Input/output:** synthetic `Stream<String>` input and `StringBuffer` output,
  plus a public `TerminalSession.run` scope for the shared-session scenarios.
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

Deliberate visible changes in this revision: `DurationInput`'s opening sentence
is now a compact mode cue (the previous opening repeated the whole grammar), its
live interpretation writes to the shared session output, and its component help
retains the exact-microsecond and maximum-magnitude rules. `README.md` now
documents the compact cue/help split, the `instructions`, `supplementaryHelp`
and `ColorTheme` options, and the shared `terminal`/`outputProfile`/`session`
invocation arguments for these six inputs.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/duration_input.dart test/formatted_values_migration_test.dart` | Passed: 2 files checked, 0 changed |
| `dart test test/formatted_values_migration_test.dart test/number_input_test.dart test/network_input_test.dart test/email_input_test.dart test/color_input_test.dart test/duration_input_test.dart --reporter expanded` | Passed: 64 tests |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: 152 relative links in 43 Markdown files |
| `dart test --reporter compact` | Passed: 724 tests |

A mutation check confirmed the suite detects a removed active-format cue
(`PortInput is missing its cue`) and, before the fix, detected both the verbose
duration opening and the duration interpretation written outside the shared
session output.

## Limitations

This record is deterministic scripted public-behavior evidence at the listed
implementation revision. It is not native PTY, visible-terminal, screen-reader,
resize/short-screen, modal-help, fault-injection, Linux/macOS CI or final
backend-gate evidence; those remain owned by their dedicated tickets and the
final evidence gate. It covers no component outside the six listed inputs and
makes no whole-library accessibility claim.

Two further limitations are recorded rather than waived:

- The colour preview, email interpretation and duration interpretation lines
  are written to the session-owned output sink directly, as the pre-existing
  colour and email previews already did. The editor change callback writes them
  synchronously, so they are not driven by another producer, but they are not
  routed through the session's serialized writer and no shared-writer failure
  during a preview is exercised here.
- A repository-wide `dart format --output=none --set-exit-if-changed .` still
  reports three files from earlier tickets (`test/linear_text_input_events_test.dart`,
  `test/native_text_input_capabilities_test.dart`,
  `test/terminal_session_short_screen_test.dart`). They are untouched by this
  ticket and the failure is identical at the merged integration revision.
