# Ticket 26 — Slider, RangeSlider and MaskedInput migration

**Status:** pass for the scripted public range/mask prompt seam.

## Source and environment

- **Implementation revision:** `0d0f7ea21677c7a2909b0a54897143d42a6b6a37`. It
  follows `2764317` (moving the slider family into its own library part),
  `f468ca3` (`Slider`), `22fec80` (`RangeSlider`), `89904d9` (`MaskedInput`),
  `d4ce279` (stage-led help and layout coverage) and `7336353` (README).
- **Branch:** `ticket/backend-26-range-mask-migration`, based on integration
  `9d6ecbe` (`Merge branch 'ticket/backend-17-failure-recovery'`); the
  integration tip was unchanged when the branch was merged before this report.
- **Date:** 2026-11-13.
- **Environment:** Windows 11 (`10.0.26200`), Dart SDK `3.13.2 (stable)`,
  `windows_x64`, commands run in the ticket worktree
  `prompty-backend-ticket-26`.
- **Input/output:** synthetic scripted string streams and `StringBuffer`
  output, plus public `TerminalSession.run`, `Spinner`, `ScriptedInput`,
  `OutputProfile`, `TerminalResizeObserver`, `TerminalIo` and typed
  `PromptResult` observations.
- **Profiles:** explicitly declared rich 40×8, 30×8 and 16×6 ASCII monochrome
  profiles with cursor support, an 18×6 narrow profile, a 14×5 and a 3×6 idle
  resize observation. No geometry is read from the host terminal and no test
  depends on the developer's locale or environment.

## Public behavior exercised

`test/range_mask_migration_test.dart` (23 tests) drives only public
constructors and `prompt`, and records that:

- `Slider` and `RangeSlider` resolve the invocation/source/legacy
  output-profile precedence: an explicit rich profile is honoured even when the
  legacy rich hint is false, an explicitly requested rich mode without declared
  cursor support and positive geometry is `Unavailable`, and `automatic` mode
  falls back to linear entry without rich facts;
- `Slider` keeps its decimal-string result and `RangeSlider` its
  `(String, String)` record; bounds, step grid, units, precision and the
  range minimum gap keep their previous meaning, and an adjustment that would
  cross the gap boundary is refused while both endpoints keep their roles;
- rich and linear help lead with the requesting stage (`Help: Adjusting the
  value`, `Help: Editing the value`, `Help: Submit`, `Help: Entering the
  value`, `Help: Adjusting the Lower endpoint`, `Help: Entering the
  endpoints`) and keep the accepted bounds, step, units, precision and pair
  review in the same block; linear `/help` also names `/cancel` and the quoting
  rule, and dismissing help restores the draft;
- guidance for both families wraps inside the declared geometry (each physical
  line is measured against the declared column count in rich and linear mode);
- `Slider` and `RangeSlider` repaint on an idle resize notification without
  changing or accepting the draft, and the observation subscription is released
  when the prompt exits;
- `Slider` and `RangeSlider` run inside `TerminalSession.run` with a `Spinner`
  repainting the shared screen, and inherit the session input, output and
  profile;
- an explicit `TerminalIo` adapter is acquired and restored exactly once for
  `Slider` and `MaskedInput`;
- `MaskedInput` resolves the same profile precedence and rich refusal for fixed
  and adaptive templates;
- the fixed-template rich editor maps the field-local caret into an inline
  draft (`1-[2]`, `1-2|`), clips that draft around the focused slot with
  truthful `<`/`>` overflow markers at 18 columns, and falls back to a stacked
  slot/literal list when the focused field cannot fit; navigation keys are
  unchanged;
- `MaskedInput` rich help (new path for a fixed template) leads with the focused
  slot or the submit stage and keeps the template shape — slot numbers,
  descriptions, required flags and literal text — beside it; linear help keeps
  the `/edit`, `/value`, `/review` and `/done` correction workflow and the
  raw-versus-formatted rule;
- `MaskedInput` repaints at a new idle geometry with its slots intact and
  releases the watcher;
- both modes keep partial drafts, validation and every terminal outcome
  (`Accepted`, `Cancelled`, `Interrupted`, `InputEnded`, `Unavailable`) for all
  three components;
- a failed shared writer surfaces the original failure from an attached
  `RangeSlider`, retires the session and rejects a late registration, so
  ticket 17 behaviour is preserved for this family.

The existing `test/slider_test.dart` (16 tests) and `test/masked_input_test.dart`
(36 tests) continue to cover exact decimal arithmetic, precision and grid
rejection, endpoint ordering and review, concurrency rejection and reuse,
combining-mark slot joins, paste atomicity and capacity rejection, adaptive
template ambiguity, interpretation provenance and the decoding work limit. Those
suites now declare a synthetic rich profile wherever they request rich
interaction, per the shared profile contract.

Implementation notes:

- `Slider`, `RangeSlider` and `MaskedInput` accept `terminal`, `outputProfile`
  and `session`; an attached prompt goes through `TerminalSession._promptRunner`
  and inherits session input, output, mode and profile.
- All three resolve `OutputProfile.resolve(invocation:, source:, supportsRich:)`
  and `_constrainToObservedGeometry`, apply `NO_COLOR`, refuse an explicitly
  requested rich mode that the effective profile cannot support, and select rich
  only for `automatic` when the profile permits rich interaction.
- `Slider` and `RangeSlider` moved into `lib/src/range_input.dart`, a new part
  of the shared library, so the migration does not collide with concurrent
  component migrations in `lib/src/text_input.dart`. Moving the family is
  behaviour-preserving and keeps the public library surface unchanged.
- New guidance uses `_writeWrappedText` at `_textInputWidth(effectiveProfile)`,
  recomputed per repaint so a resize re-wraps. `MaskedInput` routes its notices
  through a small width-aware sink for the same reason.
- `_watchIdleResize` (shared, `lib/src/text_input.dart`) implements the idle
  repaint for transcript-style rich loops: it updates the effective geometry,
  skips repaint while help owns the screen, delivers a failed repaint to the key
  reader instead of retrying a dead writer (ticket 17 behaviour), and returns the
  stop callback every exit calls.
- `_edit` now keeps component linear help when the flow also advertises exact
  commands; previously a command-aware flow silently replaced the component help
  with the generic command list.
- Session repaint registration is restored after a nested editor returns, so
  feedback compaction keeps repainting the prompt.

## Executed verification

| Command | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib/src/masked_input.dart lib/src/range_input.dart lib/src/text_input.dart test/masked_input_test.dart test/slider_test.dart test/range_mask_migration_test.dart` | Passed: `Formatted 6 files (0 changed)`. |
| `dart analyze` | Passed: `No issues found!`. |
| `dart test test/range_mask_migration_test.dart test/slider_test.dart test/masked_input_test.dart --reporter compact` | Passed: 75 tests. |
| `dart test test/component_acceptance_matrix_test.dart --reporter compact` | Passed: 144 tests. |
| `dart run tool/check_doc_links.dart` | Passed: `Checked 152 relative links in 42 Markdown files.` |
| `dart test --reporter compact` | Passed: 737 tests. |

The repository-wide `dart format --output=none --set-exit-if-changed .` still
reports three files changed (`test/linear_text_input_events_test.dart`,
`test/native_text_input_capabilities_test.dart`,
`test/terminal_session_short_screen_test.dart`). Those files are unmodified by
this ticket and already failed that check on the integration tip `9d6ecbe`
with this SDK, so the ticket records the failure instead of reformatting
unrelated files.

One intermediate full-suite invocation at this revision exited non-zero, but the
failing test name was not captured before the run was repeated. Five subsequent
full-suite runs at the same revision passed all 737 tests. That single run is
recorded as unexplained rather than as a pass or a known regression.

## Limitations

This is deterministic scripted public-behavior evidence. It is not native
terminal or PTY evidence, not visible-terminal GUI or NVDA evidence, and not
Linux/macOS CI evidence; those remain owned by tickets 31, 32 and the final
evidence gate. No human usability or whole-library accessibility claim is made.

- **Resize notification contract:** the range and mask editors subscribe once
  per outer repaint and once per nested `_edit`, so the observer's
  `notifications` stream must support repeated listens (a broadcast stream, as
  used by the evidence fixtures). A single-subscription stream would fail on the
  second editor. This ticket neither changes nor adds evidence for the native
  adapter that supplies that stream.
- **Wrapping shape:** `_writeWrappedText` wraps by display cell rather than word
  boundary, so a word can be split across physical lines. Guidance content is
  preserved but not word-wrapped.
- **Rich vertical overflow** is only observable as transcript scrollback; these
  tests assert physical line widths and retained drafts, not a scrolled live
  viewport.
- **Inline mask layout is a single logical line:** because these prompts paint a
  transcript repaint per key rather than a cursor-addressed editor, each
  repaint appends a new draft line. The `<`/`>` overflow markers describe the
  declared width, not a scrolled sub-window of a live viewport.
- **Empty slots render as nothing inside the inline draft** (matching
  `MaskedValue.formatted`); the focused slot is always bracketed, so an empty
  focused slot appears as `[]`. Empty non-focused slots are therefore only
  visible through the stacked layout or component help.
- **No colour parameter:** these three prompts still have no `ColorTheme`
  constructor argument and emit no owned colour spans. Colour roles for this
  family are unrelated to this ticket's acceptance references and remain
  unverified here.
- **No `InstructionDisplay` parameter:** instruction-presentation overrides are
  still only implemented for `TextInput`; the range and mask families always show
  the compact hint and the help route, so the instruction-policy matrix is not
  exercised for them.
- **Lone trailing Escape:** a scripted stream that ends with a bare `ESC`
  reports `InputEnded` because the escape disambiguation timer is cancelled when
  the stream closes; the evidence therefore cancels with `ESC` followed by
  another byte. This is pre-existing shared key-parser behavior, unchanged here.
- **Modal help on an alternate screen** is not exercised for this family: the
  rich fixtures declare cursor support but not alternate-screen support, so the
  evidence covers the transcript help fallback only.
