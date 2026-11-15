# 26: Migrate sliders, ranges and MaskedInput

**Parent:** [Trelis declarative theming and backend foundation](../../trelis-theming/spec.md)

**What to build:** Adjust bounded values and masked templates on shared typed controls while retaining exact answer semantics.

**Blocked by:**
- [13: Run a prompt alongside one Spinner and coordinated Text messages](13-prompt-live-status.md)

**Status:** resolved

**Acceptance reference:** [B-PARITY](../../trelis-backend-implementation/spec.md#b-parity), [B-MEASURE](../../trelis-backend-implementation/spec.md#b-measure), [B-HELP](../../trelis-backend-implementation/spec.md#b-help).

- [x] Preserve decimal-string and range-record results, precision, steps and minimum-gap constraints.
- [x] Retain slot/literal/template interpretation, raw/formatted editing and ambiguity/review workflow.
- [x] Map focus and field-local caret through inline/stacked and clipped layouts without altering behavior-owned navigation.
- [x] Supply missing relevant help and essential format/state/action content.
- [x] Verify actual public rich/linear tasks, partial input, resize, validation and all terminal outcomes.

- [x] Record actual public-behavior verification, source revision, environment, results and evidence limitations; do not treat this ticket's publication as implementation or a test pass.

## Comments

Merged into integration as `50e40b1`. Retained component help plus exact advertised commands in shared help dispatch. Corrected shared wrapping to preserve separator spaces at line boundaries while retaining ticket 21's atomic marker protection; this fixed four merged range/mask failures without weakening assertions. Post-merge: analysis, changed-file formatting and doc links passed; 85 range/mask/failure tests, 95 selection/multiline/tag tests, 144 component-matrix tests passed; full suite passed 783 tests on three consecutive runs. The earlier unexplained ticket-branch failure did not recur and remains recorded, not retroactively classified as a pass. Native/GUI/cross-platform gates remain pending.

## Answer

Implemented on `ticket/backend-26-range-mask-migration` in commits `2764317`
(move the slider family into its own library part), `f468ca3` (`Slider`),
`22fec80` (`RangeSlider`), `89904d9` (`MaskedInput`), `d4ce279` (stage-led help
and layout coverage), `7336353` (README), `f401636` and `706c6fe` (evidence)
and `0d0f7ea` (ticket 17 writer-failure coverage), based on integration
`9d6ecbe`. Merging the latest integration tip into the branch was a no-op
("Already up to date") and that tip was unchanged when this report was written;
ticket 17's shared-writer failure handling and every other merged migration are
intact. Merging this branch into integration is deliberately left to the parent.

`Slider`, `RangeSlider` and `MaskedInput` now resolve the invocation/source/
legacy output-profile precedence, refuse an explicitly requested rich mode the
profile cannot support, constrain the profile to observed geometry, apply
`NO_COLOR` through that resolved profile (these prompts still emit no colour
spans), and accept `terminal`, `outputProfile` and `session`. An attached prompt
inherits its session input, output and profile, reads the session-owned key
stream, repaints through the session writer, and restores repaint registration
after a nested editor returns. `Slider` and `RangeSlider` moved into
`lib/src/range_input.dart` (a part of the shared library) so the migration
touched `lib/src/text_input.dart` only for the `part` directive, one new
`_watchIdleResize` helper and one help-only `_edit` fix.

Answer semantics are unchanged: `Slider` still returns the exact decimal string
and `RangeSlider` the `(String, String)` record; bounds, step grid, units,
precision, the `Lower,Upper` supplied spelling and the minimum-gap ordering rule
keep their meaning, and an adjustment that would cross the gap boundary is
refused while both endpoints keep their roles. `MaskedInput` keeps one-grapheme
slots, literal formatting, raw/formatted interpretation provenance, optional
slot placements, template ambiguity and resolution, paste atomicity, the
decoding work limit and the linear `/edit`, `/value`, `/review`, `/done`
workflow.

Presentation now leads with the requesting stage in both modes —
`Help: Adjusting the value`, `Help: Editing the value`, `Help: Submit`,
`Help: Entering the value`, `Help: Adjusting the Lower endpoint`,
`Help: Entering the endpoints`, `Help: Editing slot N`, `Help: Submitting`,
`Help: Entering a raw or formatted value`, `Help: Choosing a template` — and
keeps the accepted bounds, step, units, precision, pair review or slot/literal
shape in the same block. The previously missing fixed-template rich help path
exists (Ctrl+T), linear `/help` now keeps component help when the flow also
advertises exact commands, and `MaskedInput` maps the field-local caret into an
inline draft (`1-[2]`, `1-2|`), a clipped window around the focused slot with
truthful `<`/`>` markers, or a stacked slot/literal list when that slot cannot
fit. Navigation keys are untouched. Guidance wraps inside the declared geometry
and an idle resize repaints without changing or accepting the draft.

Verification on Windows 11 (`10.0.26200`) with Dart SDK 3.13.2
(`windows_x64`): `dart format --output=none --set-exit-if-changed` on the six
changed source/test files reported `Formatted 6 files (0 changed)`; the new
`test/range_mask_migration_test.dart` (23 tests) plus `test/slider_test.dart`
(16) and `test/masked_input_test.dart` (36) passed 75 tests; the component
acceptance matrix passed 144 tests; `dart analyze` reported no issues;
`dart run tool/check_doc_links.dart` checked 152 links in 43 files; and the full
suite passed 737 tests. Code and tests are at revision `0d0f7ea`; the final run
was repeated at HEAD `0b0ce7a`, which changes only this record's wording.
Evidence, source revision, environment, commands, expected/actual results and
limitations are recorded in
`doc/evidence/trelis-backend/26-range-mask-migration.md`.

Limitations: this is scripted public-behavior evidence only. Native PTY,
Linux/macOS CI, visible-terminal GUI/NVDA, alternate-screen modal help for this
family and the final evidence gate remain outstanding. The resize observers must
support repeated listens per prompt, wrapping splits at display cells rather than
word boundaries, each rich mask repaint appends a transcript draft line rather
than painting a cursor-addressed viewport, empty non-focused slots are absent
from the inline draft (visible via stacked layout or help), these prompts still
have no `ColorTheme` or `InstructionDisplay` argument, and three unrelated test
files already failed the repository-wide format check on the integration tip.
One intermediate full-suite run at this revision exited non-zero without its
failing test being captured; five later full runs at the same revision passed,
so that single run is recorded as unexplained rather than as a pass.
