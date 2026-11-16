# Theme component inventory

The retained [theme atlas](../example/prototype-themes/index.html) contains
**45 themes × 40 named component specimens = 1,800 visual specimens**. The
[structures page](../example/prototype-themes/structures.html) separates those
color themes from their **15 shared structural grammars**.

These names are copied exactly, in source order, from `COMPONENTS` in
[`generate.py`](../example/prototype-themes/generate.py). They are design-study
names, not an implemented or finalized Dart API. For example, the runtime
prototype called its text field “Input,” but the atlas names it `TextInput`.

## The 40 components used to make the themes

1. `TextInput`
2. `Password`
3. `NumberInput`
4. `Multiline`
5. `Autocomplete`
6. `Confirm`
7. `Select`
8. `MultiSelect`
9. `SearchSelect`
10. `Checkbox`
11. `Radio`
12. `TreeSelect`
13. `Toggle`
14. `Slider`
15. `DateInput`
16. `TimeInput`
17. `PathInput`
18. `Keypress`
19. `Text`
20. `Progress`
21. `Spinner`
22. `MultiSpinner`
23. `TagInput`
24. `MaskedInput`
25. `RegexInput`
26. `URLInput`
27. `EmailInput`
28. `ColorInput`
29. `FilePicker`
30. `DirectoryPicker`
31. `PortInput`
32. `IPAddressInput`
33. `DurationInput`
34. `CronInput`
35. `TimezoneSelect`
36. `RangeSlider`
37. `SortableSelect`
38. `KeyChordInput`
39. `StepperForm`
40. `CommandPalette`

## Current implementation-planning scope

The atlas inventory above remains **40 historical specimens**. The current
Trelis interaction-planning effort covers **38 components**: `StepperForm` is
deferred, and the user removed `RegexInput` from the planned component set.
Regex-based input validation is also deferred to later; it is not a replacement
component being designed in this effort.

See the [planning map](../docs/issues/trelis-accessible-prompts/map.md) for current
scope boundaries and decision context. Existing research that counted 39
non-form specimens predates the removal of `RegexInput`.

## DateInput interaction scope

The planned `DateInput` includes **slash-separated date entry**, such as
`YYYY/MM/DD`. This clarifies the existing component rather than adding a new
specimen to the forty-component atlas. The static reference shows
`2026 / [11] / 18`; its year-first order is an example, not the runtime default.
The resolved [locale-calendar DateInput contract](../docs/issues/trelis-accessible-prompts/issues/17-locale-calendar-date-contract.md)
holds the system-convention, calendar-context, editing and verification decisions.
This inventory does not specify a month-grid calendar or a `/` key that opens one.

## The four specimens shown on the structures page

The anatomy page compares the 15 grammars using these four components:

- `Select`
- `TextInput`
- `StepperForm`
- `MultiSpinner`

This is a subset of the forty-component atlas, not a different inventory.

## Structure versus theme versus component

- **Component:** the interaction or feedback being depicted, such as
  `TextInput`, `Select` or `MultiSpinner`.
- **Structure:** the layout grammar—rails, borders, indentation, grouping,
  markers and helper placement. The 15 IDs are `rail`, `minimal`, `ascii`,
  `box`, `bracket`, `round`, `form`, `chevron`, `plain`, `double`, `branch`,
  `line`, `block`, `ledger` and `colon`.
- **Theme:** the color and character vocabulary applied to a structure.
  Multiple themes can share one structure.

The pictures and HTML are static design references. The runtime trials covered
only Input/TextInput, Select and MultiSelect, and only three representative
structures. Their implementation and tests remain on the archived prototype
branch; [terminal-backend.md](terminal-backend.md) records the backend decision
and the required local Dart TUI patch.
