# Ticket 09 — TextInput colour rendering evidence

- **Revision:** `ticket/backend-09-colour-rendering` tip at evidence execution, based on integration `93aa6ec`.
- **Environment:** Windows; Dart SDK as selected by the repository.
- **Public seam:** `TextInput(..., colors: ColorTheme(...)).prompt(source: ScriptedInput(...))`.

## Executed verification

- `dart test test/output_profile_text_input_test.dart test/text_input_colour_rendering_test.dart --reporter expanded`: 10 tests passed.
- `dart analyze`: no issues found.
- `dart test --reporter expanded`: initially ran after the change and found one legacy assertion expecting no colour SGR from the default palette. The renderer was corrected so terminal-default roles emit no SGR, then the focused command above passed. The full suite must be rerun at the final merged revision.

## Observed behavior and limits

The focused tests use an explicit synthetic RGB profile and assert composed RGB foreground/component-local background SGR plus reset; `ColorDepth.none` keeps the label and emits no colour SGR. Bounds rejection and palette copy construction are covered. Native/scripted hard restrictions use known nonempty `NO_COLOR` and real-stream attachment facts; this record does not claim a real terminal's palette slots, RGB fidelity, font, or dark/light surface were measured.

## Final-review revalidation

The final backend review found that the opening label/context and the validation
line were coloured before wrapping, so the safety renderer spelled the style out
as literal text, and that validation never received the palette error role.
Both are fixed on `ticket/backend-final-review-fixes` (`06aad38`) with public
red/green tests in `test/text_input_colour_rendering_test.dart`, and
`terminalSgr` no longer names an ANSI-16 colour for a depth that cannot show
one. See [final-review-fixes.md](final-review-fixes.md).


