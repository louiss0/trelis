# Proposed structural-theme factory signatures

Derived from the [source API baseline](api-baseline.md) at revision `80f4752e16a6e3b2451f2b87b9450e535ae3fa30` and the approved [factory/colour decision](issues/03-static-theme-api-and-colours.md).

Each of the fifteen structural classes exposes these 38 typed methods. Interactive methods add colours, instruction display and supplementary help; feedback methods add colours only. Signatures below are declaration notation with intentionally omitted bodies, not runnable current APIs. Preserve constructor behavior, generic types and parameter defaults; test forwarding using distinguishable non-default arguments and compile-time fixtures. Session/output/profile configuration remains on invocation methods and does not belong in these factories.

## Signature group 1

```dart
// Constructor: lines 87–99.
static TextInput textInput(
  String label, {
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1019–1025; field types: 1033–1037.
static Password password(
  String label, {
  String initialValue = '',
  bool mask = false,
  bool required = false,
  String? Function(String)? validate,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1194–1195.
// Inherited parameter types: lines 1211–1218.
static Confirm confirm(
  String label, {
  bool initialValue = false,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1199–1200.
// Inherited parameter types: lines 1211–1218.
static Checkbox checkbox(
  String label, {
  bool initialValue = false,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1204–1205.
// Inherited parameter types: lines 1211–1218.
static Toggle toggle(
  String label, {
  bool initialValue = false,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1371–1377; field types: 1389–1393.
static Multiline multiline(
  String label, {
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 1799–1800.
// Inherited parameter declarations/types: lines 1808–1826.
static Select<T> select<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: line 1804.
// Inherited parameter declarations/types: lines 1808–1826.
static Radio<T> radio<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 2024–2031.
static MultiSelect<T> multiSelect<T>(
  String label,
  List<Choice<T>> choices, {
  List<T> defaultValues = const [],
  int min = 0,
  int? max,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 2368–2376; field types: 2402–2408.
static Slider slider(
  String label, {
  required String minimum,
  required String maximum,
  required String step,
  String? initialValue,
  int? precision,
  String? units,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 2621–2631; field types: 2652–2654.
static RangeSlider rangeSlider(
  String label, {
  required String minimum,
  required String maximum,
  required String step,
  String minimumGap = '0',
  String? initialLower,
  String? initialUpper,
  int? precision,
  String? units,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 2950–2955; field types include line 2979.
static TreeSelect<T> treeSelect<T>(
  String label,
  List<TreeNode<T>> nodes, {
  bool Function(T value)? isCurrent,
  T? defaultValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 3285–3290; field types: 3298–3301.
static TimeInput timeInput(
  String label, {
  bool twelveHour = false,
  bool seconds = false,
  String? initialValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

// Constructor: lines 3509–3514; field types: 3519–3522.
static TagInput tagInput(
  String label, {
  TagStyle style = TagStyle.kebabCase,
  int? maxLength,
  String? Function(String)? validate,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 2

```dart
static Autocomplete autocomplete(
  String label, {
  required FutureOr<List<String>> Function(String) suggestions,
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 3

```dart
static SearchSelect<T> searchSelect<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 4

```dart
static SortableSelect<T> sortableSelect<T>(
  String label,
  List<Choice<T>> choices, {
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 5

```dart
static CommandPalette<T> commandPalette<T>(
  String label,
  List<Choice<T>> commands, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 6

```dart
static MaskedInput maskedInput(
  String label, {
  required List<MaskTemplate> templates,
  MaskedValue? initialValue,
  MaskInterpretation interpretation = MaskInterpretation.automatic,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 7

```dart
static NumberInput numberInput(
  String label, {
  NumericConvention? convention,
  NumericConvention? Function()? conventionProvider,
  bool decimal = false,
  String? minimum,
  String? maximum,
  int? precision,
  bool required = true,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 8

```dart
static PortInput portInput(
  String label, {
  bool allowZero = false,
  String initialValue = '',
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

static IPAddressInput ipAddressInput(
  String label, {
  bool cidr = false,
  bool scoped = false,
  String initialValue = '',
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 9

```dart
static URLInput urlInput(
  String label, {
  required Set<String> allowedSchemes,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

static EmailInput emailInput(
  String label, {
  bool smtpUtf8 = false,
  String initialValue = '',
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 10

```dart
static ColorInput colorInput(
  String label, {
  bool required = true,
  String initialValue = '',
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 11

```dart
static CronInput cronInput(
  String label, {
  required CronProfile profile,
  String initialValue = '',
  CronPreviewConfig? preview,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 12

```dart
static TimezoneSelect timezoneSelect(
  String label, {
  String? defaultValue,
  Map<String, String> unavailable = const {},
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 13

```dart
static PathInput pathInput(
  String label, {
  String? base,
  String initialValue = '',
  bool allowNonexistent = false,
  PathTarget target = PathTarget.any,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 14

```dart
static FilePicker filePicker(
  String label, {
  String? base,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

static DirectoryPicker directoryPicker(
  String label, {
  String? base,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 15

```dart
static Keypress keypress(
  String label, {
  bool requireObservation = false,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});

static KeyChordInput keyChordInput(
  String label, {
  bool requireObservation = false,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 16

```dart
static DurationInput durationInput(
  String label, {
  required DurationInputMode durationMode,
  bool signed = false,
  bool allowZero = true,
  int? minimumMicroseconds,
  String? initialValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 17

```dart
static DateInput dateInput(
  String label, {
  DateFieldOrder? order,
  DateCalendar? calendar,
  DateDigits? digits,
  String? initialValue,
  ColorTheme colors = ColorThemes.terminalDefault,
  InstructionDisplay instructions = InstructionDisplay.themeDefault,
  List<String> supplementaryHelp = const [],
});
```

## Signature group 18

```dart
// Constructor: line 23; field types: 24–25.
static Text text(
  String content, {
  TextKind kind = TextKind.ordinary,
  ColorTheme colors = ColorThemes.terminalDefault,
});

// Constructor: lines 44–49; field types: 55–57.
static Progress progress(
  String label, {
  int? total,
  Duration interval = const Duration(seconds: 5),
  int milestone = 10,
  ColorTheme colors = ColorThemes.terminalDefault,
});

// Constructor: line 198; field type: 199.
static Spinner spinner(String label, {
  ColorTheme colors = ColorThemes.terminalDefault,
});

// Constructor: lines 271–274; interval field type: 290.
static MultiSpinner multiSpinner(
  Iterable<String> tasks, {
  Duration interval = const Duration(seconds: 5),
  ColorTheme colors = ColorThemes.terminalDefault,
});
```
