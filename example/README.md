# Every component under every structural theme

The 15 structural themes each own a folder, and every folder contains one
runnable Dart file for each of the 38 public components: **15 × 38 = 570
examples**. No component is shown under only one theme.

```powershell
dart run example/rail/text_input.dart
```

Every file shows exactly **one** component with one structural theme (its
folder's namespace) and one colour theme (fixed per component across all
folders). Add `--scripted` to replay a fixed linear answer; redirected output
replays it automatically. The four feedback components (Text, Progress, Spinner
and MultiSpinner) need no input.

`example/support/one_component.dart` is the shared runner, not an example.
The static HTML atlas lives in `assets/prototype-themes/`; no Python or HTML
file is in this folder.

## Structural theme folders

| Folder | Namespace | Example run |
|---|---|---|
| rail | RailTheme | `dart run example/rail/text_input.dart` |
| branch | BranchTheme | `dart run example/branch/text_input.dart` |
| box | BoxTheme | `dart run example/box/text_input.dart` |
| round | RoundTheme | `dart run example/round/text_input.dart` |
| double | DoubleTheme | `dart run example/double/text_input.dart` |
| minimal | MinimalTheme | `dart run example/minimal/text_input.dart` |
| ascii | AsciiTheme | `dart run example/ascii/text_input.dart` |
| chevron | ChevronTheme | `dart run example/chevron/text_input.dart` |
| bracket | BracketTheme | `dart run example/bracket/text_input.dart` |
| form | FormTheme | `dart run example/form/text_input.dart` |
| ledger | LedgerTheme | `dart run example/ledger/text_input.dart` |
| colon | ColonTheme | `dart run example/colon/text_input.dart` |
| line | LineTheme | `dart run example/line/text_input.dart` |
| block | BlockTheme | `dart run example/block/text_input.dart` |
| plain | PlainTheme | `dart run example/plain/text_input.dart` |

## Components and their colour themes

Each file below exists in **all 15** folders, always with the same palette.

| Component | File in every folder | Colour theme |
|---|---|---|
| Autocomplete | `autocomplete.dart` | ColorThemes.paper |
| Checkbox | `checkbox.dart` | ColorThemes.mainframe |
| ColorInput | `color_input.dart` | ColorThemes.blueprint |
| CommandPalette | `command_palette.dart` | ColorThemes.ember |
| Confirm | `confirm.dart` | ColorThemes.orchid |
| CronInput | `cron_input.dart` | ColorThemes.workbench |
| DateInput | `date_input.dart` | ColorThemes.tide |
| DirectoryPicker | `directory_picker.dart` | ColorThemes.ink |
| DurationInput | `duration_input.dart` | ColorThemes.arcade |
| EmailInput | `email_input.dart` | ColorThemes.fieldnotes |
| FilePicker | `file_picker.dart` | ColorThemes.nordic |
| IPAddressInput | `ip_address_input.dart` | ColorThemes.punch |
| KeyChordInput | `key_chord_input.dart` | ColorThemes.ledger |
| Keypress | `keypress.dart` | ColorThemes.infrared |
| MaskedInput | `masked_input.dart` | ColorThemes.porcelain |
| MultiSelect | `multi_select.dart` | ColorThemes.citrus |
| MultiSpinner | `multi_spinner.dart` | ColorThemes.lavender |
| Multiline | `multiline.dart` | ColorThemes.basalt |
| NumberInput | `number_input.dart` | ColorThemes.glacier |
| Password | `password.dart` | ColorThemes.vinyl |
| PathInput | `path_input.dart` | ColorThemes.botanical |
| PortInput | `port_input.dart` | ColorThemes.terminalAmber |
| Progress | `progress.dart` | ColorThemes.slate |
| Radio | `radio.dart` | ColorThemes.solar |
| RangeSlider | `range_slider.dart` | ColorThemes.deepSpace |
| SearchSelect | `search_select.dart` | ColorThemes.moss |
| Select | `select.dart` | ColorThemes.copper |
| Slider | `slider.dart` | ColorThemes.midnightMint |
| SortableSelect | `sortable_select.dart` | ColorThemes.typewriter |
| Spinner | `spinner.dart` | ColorThemes.neonGrid |
| TagInput | `tag_input.dart` | ColorThemes.sandstone |
| Text | `text.dart` | ColorThemes.blueHour |
| TextInput | `text_input.dart` | ColorThemes.signal |
| TimeInput | `time_input.dart` | ColorThemes.matcha |
| TimezoneSelect | `timezone_select.dart` | ColorThemes.obsidian |
| Toggle | `toggle.dart` | ColorThemes.clay |
| TreeSelect | `tree_select.dart` | ColorThemes.polar |
| URLInput | `url_input.dart` | ColorThemes.forestFloor |
