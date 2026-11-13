# Ticket 21 — selection migration evidence

**Status:** pass for the scripted public Select, Radio and MultiSelect seams.

## Source and environment

- **Implementation revision:** `fd465bf` (implementation), merged with
  `integration/trelis-backend-tracer-bullets` at `9d6ecbe` into merge revision
  `e11b9a54abd29a40ec370957f55a8875e420bf95`, which is the revision these
  results were produced and re-run at.
- **Branch:** `ticket/backend-21-selection`
- **Date:** 2026-11-13
- **Environment:** Microsoft Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK
  3.13.2 stable (`dart --version`, Tue Aug 25 01:01:12 2026 -0700).
- **Selected input/output:** synthetic `Stream<String>` input with `StringBuffer`
  output; explicitly declared rich profiles (cursor support plus positive
  geometry) for rich scenarios; one public `TerminalIo` fake that records
  acquisition/restoration; one `TerminalSession` scenario with a live `Spinner`.
- **Geometry/width policy:** default `TextDisplayMap` width policy with the
  declared profile columns (24, 40 or 80) capped at the shared 120-column cap;
  colour suppressed unless the declared profile permits it.

## Public behavior exercised

`test/select_radio_test.dart` and `test/multi_select_test.dart` invoke only the
public `Select<T>`, `Radio<T>` and `MultiSelect<T>` constructors and their
`prompt` methods. They verify that:

- results stay concretely generic (`Select<int>`, `MultiSelect<String>`), and
  `SuppliedAnswer` accepts only an enabled stable reference: `0`, out-of-range,
  a disabled reference, an empty string and a label are all `Unavailable`;
- rich and linear tasks retain defaults, focus, checked/selected, `[default]`
  and `[unavailable: reason]` state separately, including duplicate labels,
  disabled focus inspection, paging, filtering, bulk visible actions, selected
  review and `min`/`max` bounds;
- rows are composed by one shared typed choice presentation
  (`_ChoiceRow`/`_writeChoiceRow`), so a narrow declared width (24 columns)
  wraps the label but never splits `[focused]`, `[checked]`, `[default]` or
  `[unavailable: reason]`, and the stable reference keeps its displayed number;
- component help is complete for the current stage: linear `/help` names the
  reference entry rule, `/next`/`/previous` paging and the exact command rules
  for a single choice, and the toggle, `/done`, `/selected`, `/filter`,
  `/select-visible`, `/clear-visible`, paging, bounds and quoting rules for a
  multi-select; rich Ctrl+T help names navigation, toggle/submit/review/filter,
  Escape and Ctrl+C. Help includes the displayed default and every unavailable
  reason, including a choice whose page or filter is not displayed, and help
  dismissal repaints the retained focus, reason and checked draft;
- repeated rejections each restate the protected reason and the workflow
  continues to a later acceptance; warnings, acceptance, toggle, review and
  bound messages wrap inside a 40-column profile and use the component palette
  when the profile permits colour (`[38;5;12;…]` warning, `[38;5;11;…]`
  success), with `NO_COLOR` suppression inherited from the shared profile rules
  (covered by the Boolean/backend tickets for the same helper);
- every terminal outcome is distinct: `Accepted`, `Cancelled`, `Interrupted`,
  `InputEnded` (rich EOF and linear EOF) and `Unavailable` for a rich
  requirement without declared capability; `automatic` mode falls back to
  linear instead of failing;
- a declared profile and a public `TerminalIo` lease reach the prompt and are
  restored, and an attached `TerminalSession` keeps a MultiSelect draft usable
  while a `Spinner` writes feedback and repaints the checked draft above it.

`test/component_acceptance_matrix_test.dart` supplies public rich and linear
Select, Radio and MultiSelect tasks; `test/terminal_session_feedback_test.dart`
and `test/terminal_session_failure_recovery_test.dart` exercise the shared
session behavior these prompts attach to after the merge.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/select_radio_test.dart test/multi_select_test.dart` | Passed: `Formatted 3 files (0 changed)` |
| `dart analyze` | Passed: `No issues found!` |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 152 relative links in 43 Markdown files.` |
| `dart test test/select_radio_test.dart test/multi_select_test.dart --reporter expanded` | Passed: 32 tests |
| `dart test test/component_acceptance_matrix_test.dart test/terminal_session_feedback_test.dart test/terminal_session_failure_recovery_test.dart --reporter expanded` | Passed: 157 tests |
| `dart test --reporter compact` | Passed: 726 tests |

## Limitations

- This is deterministic scripted public-behavior evidence at the listed
  revision. It is not native PTY, visible-terminal, screen-reader,
  Linux/macOS CI, short-screen resize, modal-help, fault-injection or
  final-backend-gate evidence; those remain owned by their dedicated tickets
  and the final gate. It makes no whole-library accessibility claim.
- Rich presentation is written to the transcript rather than an alternate
  screen, so vertical overflow is ordinary terminal scrollback. Only
  horizontal wrapping within the declared width was verified here.
- The shared editor's own sequential status lines (`Current text:` /
  `Cursor position:`, 34 columns) are not width-wrapped; they are owned by the
  text-input tickets, so the narrow-width feedback scenario uses 40 columns.
- Existing families disagree about padded supplied references: `Select`,
  `SearchSelect` and `TreeSelect` parse with `int.tryParse` and therefore accept
  `" 1"`, while `MultiSelect` requires an exact reference. This migration
  preserves each family's current behavior instead of changing public results.
- `dart format --output=none --set-exit-if-changed .` reports three
  pre-existing unformatted files on the integration tip
  (`test/linear_text_input_events_test.dart`,
  `test/native_text_input_capabilities_test.dart`,
  `test/terminal_session_short_screen_test.dart`). They are unmodified here and
  belong to their own tickets.
