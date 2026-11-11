# Ticket 05 — safe typed TextInput rendering evidence

**Status:** partial ticket evidence; this is not backend-gate publication or a platform/native pass.

## Source and environment

- Initial base source revision: `677eb01686e52ec489ee6372534cec58659c526b`; current integration revision merged before this completion slice: `6144d21`.
- Evidence source: the ticket 05 working tree changes committed with this record.
- Date: 2026-11-11.
- OS: Microsoft Windows NT 10.0.26200.0.
- Dart: 3.13.2 stable (`windows_x64`).
- Test output: explicit `StringBuffer` scripted sinks; rich fixtures used cursor support and fixed 100×30 geometry. No physical terminal/font assertion is made.

## Public-behavior checks and results

1. `dart test test/text_input_test.dart --reporter expanded` — **pass**, 22 tests.
   - Rich and linear scripted `TextInput` accept the original answer containing U+202E while output shows `\\u{202E}` rather than a bidi control.
   - Label and validation text use the same safe display encoding; a validation message containing ESC `[2J` and U+202E is emitted as visible escapes, not terminal instructions.
   - The rich test observes save/restore anchoring (`> aX ESC[s b ESC[u`) at the public output seam after a caret move; accepted answer is `aXb`.
   - Existing validation, required, command/literal, paste, and rich/linear behavior also passed.
2. `dart test test/presentation_safety_test.dart --reporter expanded` — **pass**, 1 declaration-seam test.
   - The declaration intentionally omits relevant validation content. Its diagnostic reports `PresentationSlot.validation`, while the compositor inserts the same safe typed node in the deterministic safety area after the body.
3. `dart analyze` — **pass**, “No issues found!”.
4. `dart test test/component_acceptance_matrix_test.dart --reporter expanded` — **pass**, 144 tests covering the existing rich and linear component matrix.
5. `dart test --reporter expanded` — **not a clean pass**: 659 tests completed successfully and one unrelated full-suite occurrence of `cron_interaction_conformance_test.dart: rich preview cancellation retains review before root cancellation` failed to observe its cancellation transcript. Immediate isolated rerun, `dart test test/cron_interaction_conformance_test.dart --reporter expanded`, **passed** all 7 tests. This ticket does not treat the isolated rerun as a full-suite pass.

## Implementation coverage

TextInput now projects label/context/validation semantic slots and an immutable editable-region snapshot before output. The editable region is the sole logical caret owner. A shared typed `PresentationDeclaration`/`PresentationCompositor` surface diagnoses omissions independently of rendering and inserts any omitted relevant protected node into its deterministic safety area after the body and before optional hints. TextInput's declaration deliberately places its label/context/body and relies on that repair for relevant validation, proving the running renderer and declaration diagnostic are separate. The renderer encodes C0/C1 controls and bidi formatting/isolate controls in application/user display content; it does not transform the editor value supplied to validation or returned in `Accepted<String>`.

## Limitations

This ticket does not claim the wider backend evidence gate, Unicode cell-width policy, layout wrapping/scrolling beyond the established TextInput behavior, colour rendering, native terminal verification, CI matrix, or visible Windows GUI evidence. The local tracker was absent from this ticket worktree, so its status/checklist was not edited here.
