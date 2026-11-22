# Ticket 25 — DateInput and TimeInput migration

**Status:** pass for the scripted public date/time prompt seam.

## Source and environment

- **Implementation revision:** `8b281ecf9a967adc8a23de5e3d9f0dc5e5e3e9d4`
  (`feat:` ask/help/wrap/repaint commits below, `docs:` README and evidence
  text). The evidence commit that contains this record follows that revision.
- **Branch:** `ticket/backend-25-date-time`, based on integration
  `9d6ecbe` (`Merge branch 'ticket/backend-17-failure-recovery'`), merged into
  the ticket branch as `1413196`.
- **Date:** 2026-11-13.
- **Environment:** Windows 11 (`10.0.26200`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`, commands run in the ticket worktree.
- **Input/output:** synthetic scripted string streams and `StringBuffer`
  output, plus public `TerminalSession.run`, `Spinner`, `ScriptedInput`,
  `OutputProfile`, `TerminalResizeObserver`, `TerminalIo` and typed
  `PromptResult` observations.
- **Profiles:** explicitly declared rich 40×8 and 30×8 ASCII monochrome
  profiles with cursor support, and a 18×6 idle-resize observation. No geometry
  is read from the host terminal and no test depends on the developer's locale
  or environment.

## Public behavior exercised

`test/date_time_migration_test.dart` (10 tests) drives only public constructors
and `prompt`, and records that:

- `TimeInput` keeps hour, minute, second and period as local field drafts, so an
  incomplete time reaches review only through the explicit Edit/Submit stages;
- `DateInput` inside `TerminalSession.run` accepts an `Accepted<CivilDate>` from
  the retained draft while a `Spinner` repaints the shared screen;
- guidance wraps inside a declared narrow width without losing its content, and
  a field notice never overwrites the editable field line it follows, so the
  stacked field order stays visible;
- narrow rich and linear time prompts both keep their active-format cue
  (`minutes only; 24-hour clock`) and still return the typed record;
- rich time fields and the date review stage repaint on an idle resize
  notification without changing the draft, without accepting it early, and the
  observation subscription is released when the prompt exits;
- session help leads with the requesting stage (`Help: Review`, `Help: Editing
  the Hour field`), the background `Spinner` update is retained while help owns
  the screen, and dismissal restores the draft;
- both modes keep typed results (`CivilDate` fields including `era` and
  `inputYear`, and the time record), retain and report invalid drafts for
  correction, and keep `Cancelled`, `Interrupted` and `InputEnded` distinct.

The existing date/time suites continue to cover calendar/order/digit/era
conversion, field-local navigation, adjustment bounds without carry, review
navigation, defaults, system-profile refusal, and capability refusal.

Implementation notes:

- `DateInput` and `TimeInput` resolve the invocation/source/legacy profile
  precedence, constrain it to observed geometry, apply `NO_COLOR`, and refuse an
  explicitly requested rich mode that the effective profile cannot support.
  `automatic` mode selects rich only when the profile permits rich interaction.
- Both prompts accept `terminal`, `outputProfile` and `session`; an attached
  prompt inherits session input, output and profile, uses the session-owned key
  stream and repaints through the session writer. Ticket 17's shared-writer
  failure handling and `_edit` resize-failure delivery are unchanged.
- Every caller-side guidance line uses the shared `_writeWrappedText` at
  `_textInputWidth(effectiveProfile)`, and `_finishFieldLine` terminates the
  editable line that a control action leaves current.
- Rich field, review, formatted-entry and submit help are stage-led and keep the
  accepted format, interpretation and workflow in the same block.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/date_input.dart lib/src/text_input.dart test/date_time_migration_test.dart test/date_input_acceptance_test.dart test/date_input_action_focus_test.dart test/date_input_adjustment_test.dart test/date_input_reverse_navigation_test.dart test/date_input_review_navigation_test.dart test/date_input_rich_test.dart test/date_input_segment_test.dart test/time_input_test.dart` | Passed: `Formatted 11 files (0 changed)`. |
| `dart test test/date_input_acceptance_test.dart test/date_input_action_focus_test.dart test/date_input_adjustment_test.dart test/date_input_reverse_navigation_test.dart test/date_input_review_navigation_test.dart test/date_input_rich_test.dart test/date_input_segment_test.dart test/time_input_test.dart test/date_time_migration_test.dart --reporter compact` | Passed: 31 tests. |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | Passed: 144 tests. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 152 relative links in 43 Markdown files.` |
| `dart test --reporter compact` | Passed: 724 tests. |

The repository-wide `dart format --output=none --set-exit-if-changed .` still
reports three files changed (`test/linear_text_input_events_test.dart`,
`test/native_text_input_capabilities_test.dart`,
`test/terminal_session_short_screen_test.dart`). Those files are unmodified by
this ticket and already failed that check on the integration tip
`9d6ecbe` with this SDK, so the ticket records the failure instead of
reformatting unrelated files.

## Limitations

This is deterministic scripted public-behavior evidence. It is not native
terminal or PTY evidence, not visible-terminal GUI or NVDA evidence, and not
Linux/macOS CI evidence; those remain owned by tickets 31, 32 and the final
evidence gate. No human usability or whole-library accessibility claim is made.

- **Resize notification contract:** a date or time prompt edits several fields
  in sequence and `_edit` subscribes once per field, so the observer's
  `notifications` stream must support repeated listens (a broadcast stream, as
  used by the evidence fixtures). A single-subscription stream would fail on the
  second field. This ticket neither changes nor adds evidence for the native
  adapter that will supply that stream; the same assumption already held for the
  merged Password loop.
- **Wrapping shape:** `_writeWrappedText` wraps by display cell, so a word may be
  split across lines. Long guidance is preserved but not word-wrapped.
- **Rich vertical overflow** is only observable as transcript scrollback; these
  tests assert physical line widths and retained drafts, not a scrolled live
  viewport.
- **No colour parameter:** date and time prompts still have no `ColorTheme`
  constructor argument and emit no owned colour spans. Colour roles for this
  family are unrelated to this ticket's acceptance references and remain
  unverified here.
- **Lone trailing Escape:** a scripted stream that ends with a bare `ESC`
  reports `InputEnded` because the escape disambiguation timer is cancelled when
  the stream closes; the evidence therefore cancels with `ESC` followed by
  another byte. This is pre-existing shared key-parser behavior, unchanged here.
- **System date profile:** the Windows/Linux/macOS system-profile probes are
  exercised only as refusal or as existing platform suites; this record adds no
  new locale or calendar platform evidence.
- **Modal help on an alternate screen** is not exercised for date/time: the rich
  fixture declares cursor support but not alternate-screen support, so the
  evidence covers the transcript help fallback only.
