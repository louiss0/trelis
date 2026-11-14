# Ticket 20 — Multiline and TagInput migration evidence

**Status:** pass for the scripted public Multiline and TagInput seams.

## Source and environment

- **Implementation revision:** `3e0d59a` (`feat: run Multiline and TagInput on
  the shared backend`) on `ticket/backend-20-multiline-tags`, branched from
  integration `9d6ecbe`.
- **Date:** 2026-11-12
- **Environment:** Windows NT 10.0.26200.0 (`windows_x64`), Dart SDK 3.13.2
  stable, `dart test` on the Dart VM.
- **Input/output:** synthetic `Stream<String>` input and `StringBuffer` output,
  a public `TerminalIo` fake that records acquisition/restoration, synthetic
  `TerminalResizeObserver` fixtures and public `TerminalSession.run` scopes.
- **Rich profiles:** explicitly declared cursor support with positive geometry
  (`_rich()` = 80×24 unless a narrower width is the subject of the scenario).
  No scenario depends on the developer's terminal, environment or font.

## Public behavior exercised

`test/multiline_tag_migration_test.dart` invokes only public constructors,
`prompt` and `TerminalSession.run`:

- **Profile-driven stages.** A declared rich profile enables Multiline rich
  editing even when the legacy `supportsRich` hint is `false`; without declared
  cursor support and geometry rich mode still returns `Unavailable` and renders
  nothing.
- **Invocation compatibility.** `terminal:` acquires and restores a lease for
  both components; competing `source`/`terminal` and `output`/`terminal`
  combinations are rejected; source-only invocation without a declared profile
  keeps working in both modes; EOF, cancel and interrupt stay distinct outcomes
  in rich and linear mode for both components.
- **Multiline content rules.** Hard line breaks, literal tabs, grapheme limits,
  validation, `/list`, `/edit`, `/insert`, `/remove` review and quoted or
  identified-paste literals remain covered by `test/multiline_test.dart`; the
  migration test additionally proves rich Enter/tab/Finish behavior through the
  profile-declared seam and that the caret survives an idle repaint.
- **Tag draft separation.** A `draft` is never added without Enter, canonical
  casing is reported (`Added: hello-world`), a duplicate leaves the accepted
  collection untouched while the draft stays editable, an accepted tag is edited
  or removed in place, and `Finish` submits only the accepted collection.
- **Current-stage help.** Rich Multiline help (`Ctrl+T`) names the
  newline/finish/insert-tab editing model, wrapping, limits and validation, and
  is wrapped to the declared width. Linear `/help` is component-specific
  (`one line per Enter`, review commands, quoting, limits, validator) instead of
  the generic text-submit text. TagInput help names add, focus, edit, remove,
  discard and finish actions plus the canonical style, limit and validator.
- **Caret/focus, resize and help restoration with feedback.** A live `Spinner`
  updates while a Multiline draft is open: the session repaints the editable
  line after the status write. `Ctrl+T` transfers painting to session help,
  background updates retain their snapshot without writing into help, and
  dismissal restores the latest status plus the draft and caret. An idle resize
  repaints both components at the new width with truthful `<`/`>` markers while
  keeping the draft, accepted tags and logical caret, and the resize
  observation is cancelled on exit.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format lib/src/text_input.dart test/multiline_test.dart test/tag_input_test.dart test/multiline_tag_migration_test.dart` | Passed: files formatted |
| `dart format --output=none --set-exit-if-changed lib/src/text_input.dart test/multiline_test.dart test/tag_input_test.dart test/multiline_tag_migration_test.dart` | Passed: 0 changed |
| `dart analyze` | Passed: `No issues found!` |
| `dart test test/multiline_tag_migration_test.dart --reporter expanded` | Passed: 14 tests |
| `dart test test/multiline_test.dart test/tag_input_test.dart test/multiline_tag_migration_test.dart --reporter expanded` | Passed: 63 tests |
| `dart test test/multiline_test.dart test/tag_input_test.dart test/multiline_tag_migration_test.dart test/component_acceptance_matrix_test.dart --reporter expanded` | Passed: 207 tests |
| `dart test --reporter expanded` | Passed: 728 tests |
| `dart run tool/check_doc_links.dart` | Passed: 152 links in 43 Markdown files |

Baseline comparison: the integration base revision `9d6ecbe`, run in an
isolated worktree at the same SDK, passed 714 tests. This branch adds 14 tests
and passes 728; comparing the JSON `testStart` name sets shows the 14 new tests
and no removed existing test. The branch was re-merged with
`integration/trelis-backend-tracer-bullets` before this record; the integration
tip was still `9d6ecbe`, so no merge commit was needed and no conflict was
resolved.

## Migration notes

- Rich synthetic Multiline and TagInput now require a profile with cursor
  support and positive geometry, matching the B-COMPAT migration already applied
  to TextInput, Password and the Boolean prompts. Existing component suites were
  updated to declare that geometry; the legacy `supportsRich` hint alone no
  longer enables rich presentation.
- `_edit`'s linear `/help` branch now honours a component-supplied
  `linearHelpText` before the generic `extraCommands` listing, so help can
  describe the component's own stage. This is the shared-helper change the
  component help requires; it is behaviour-preserving for every caller that
  passes no `linearHelpText`.
- Multiline rich rendering keeps its own buffer loop (vertical navigation, Tab
  actions, literal tab insertion) and adds profile-aware width clamping, session
  repaint registration and resize observation. TagInput reuses `_edit` and now
  forwards the resolved profile, resize observer and session.

## Limitations

This record is deterministic scripted public-behavior evidence at the listed
implementation revision. It is **not** native PTY, visible-terminal,
screen-reader, Linux/macOS CI, fault-injection or final backend-gate evidence;
those remain owned by tickets 31, 32 and 33. `dart format
--output=none --set-exit-if-changed .` also reports three unrelated files
(`test/linear_text_input_events_test.dart`,
`test/native_text_input_capabilities_test.dart`,
`test/terminal_session_short_screen_test.dart`) that are already unformatted at
the integration base revision; they were left untouched. No whole-library
accessibility claim is made, and no clipboard, NVDA or font-dependent claim is
implied by the tab and line-separator scenarios. Components that re-enter the
shared editor (TagInput per tag, TextInput per validation retry) subscribe to
`TerminalResizeObserver.notifications` again, so an observer must offer a
re-listenable stream; the fixture in this evidence uses a broadcast stream.
