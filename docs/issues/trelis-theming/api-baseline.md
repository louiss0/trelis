# Trelis API inventory baseline

Source revision: `80f4752e16a6e3b2451f2b87b9450e535ae3fa30` (working-tree production sources unchanged when captured).

Read-only source-derived inventory. This is a planning asset, not compiled factory implementation. Defaults are constructor parameter defaults, not substituted internal effective defaults. Revalidate against the implementation revision before forwarding changes.

## Existing constructor surface: all 38 implemented classes

These are signature-only static-method declarations derived from the existing public unnamed constructors. Constructor field-formals and super-formals are expanded to their declared types. Positional/named placement, `required`, generics, and defaults are preserved. No presentation parameters have been added.

Method names use lowerCamelCase, including `ipAddressInput` and `urlInput`. Semicolons are signature notation; bodies are intentionally omitted.

### Core prompts — 14 classes

Source: `lib/src/text_input.dart`

```dart
// Constructor: lines 87–99.
static TextInput textInput(
  String label, {
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
});

// Constructor: lines 1019–1025; field types: 1033–1037.
static Password password(
  String label, {
  String initialValue = '',
  bool mask = false,
  bool required = false,
  String? Function(String)? validate,
});

// Constructor: lines 1194–1195.
// Inherited parameter types: lines 1211–1218.
static Confirm confirm(
  String label, {
  bool initialValue = false,
});

// Constructor: lines 1199–1200.
// Inherited parameter types: lines 1211–1218.
static Checkbox checkbox(
  String label, {
  bool initialValue = false,
});

// Constructor: lines 1204–1205.
// Inherited parameter types: lines 1211–1218.
static Toggle toggle(
  String label, {
  bool initialValue = false,
});

// Constructor: lines 1371–1377; field types: 1389–1393.
static Multiline multiline(
  String label, {
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
});

// Constructor: lines 1799–1800.
// Inherited parameter declarations/types: lines 1808–1826.
static Select<T> select<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
});

// Constructor: line 1804.
// Inherited parameter declarations/types: lines 1808–1826.
static Radio<T> radio<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
});

// Constructor: lines 2024–2031.
static MultiSelect<T> multiSelect<T>(
  String label,
  List<Choice<T>> choices, {
  List<T> defaultValues = const [],
  int min = 0,
  int? max,
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
});

// Constructor: lines 2950–2955; field types include line 2979.
static TreeSelect<T> treeSelect<T>(
  String label,
  List<TreeNode<T>> nodes, {
  bool Function(T value)? isCurrent,
  T? defaultValue,
});

// Constructor: lines 3285–3290; field types: 3298–3301.
static TimeInput timeInput(
  String label, {
  bool twelveHour = false,
  bool seconds = false,
  String? initialValue,
});

// Constructor: lines 3509–3514; field types: 3519–3522.
static TagInput tagInput(
  String label, {
  TagStyle style = TagStyle.kebabCase,
  int? maxLength,
  String? Function(String)? validate,
});
```

### Suggestion and choice parts — 4 classes

Source: `lib/src/autocomplete.dart`, constructor lines 5–18; field types lines 20–25.

```dart
static Autocomplete autocomplete(
  String label, {
  required FutureOr<List<String>> Function(String) suggestions,
  String initialValue = '',
  bool required = false,
  String? Function(String)? validate,
  int? maxLength,
});
```

Source: `lib/src/search_select.dart`, constructor lines 5–12; callback type line 65.

```dart
static SearchSelect<T> searchSelect<T>(
  String label,
  List<Choice<T>> choices, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
});
```

Source: `lib/src/sortable_select.dart`, constructor lines 5–6; label type line 14.

```dart
static SortableSelect<T> sortableSelect<T>(
  String label,
  List<Choice<T>> choices,
);
```

Source: `lib/src/command_palette.dart`, constructor lines 6–16.

```dart
static CommandPalette<T> commandPalette<T>(
  String label,
  List<Choice<T>> commands, {
  T? defaultValue,
  FutureOr<List<Choice<T>>> Function(String query)? search,
});
```

### Specialized input parts — 10 classes

Source: `lib/src/masked_input.dart`, constructor lines 55–60; initial-value field type line 96.

```dart
static MaskedInput maskedInput(
  String label, {
  required List<MaskTemplate> templates,
  MaskedValue? initialValue,
  MaskInterpretation interpretation = MaskInterpretation.automatic,
});
```

Source: `lib/src/number_input.dart`, constructor lines 523–532; field types lines 548–555.

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
});
```

Source: `lib/src/network_input.dart`, constructors line 5 and lines 64–69; boolean field types lines 21 and 85–86.

```dart
static PortInput portInput(
  String label, {
  bool allowZero = false,
  String initialValue = '',
});

static IPAddressInput ipAddressInput(
  String label, {
  bool cidr = false,
  bool scoped = false,
  String initialValue = '',
});
```

Source: `lib/src/url_email_input.dart`, constructors lines 5–6 and line 194; field types lines 15–16 and 205.

```dart
static URLInput urlInput(
  String label, {
  required Set<String> allowedSchemes,
});

static EmailInput emailInput(
  String label, {
  bool smtpUtf8 = false,
  String initialValue = '',
});
```

Source: `lib/src/color_input.dart`, constructor line 25; `required` field type line 41.

```dart
static ColorInput colorInput(
  String label, {
  bool required = true,
  String initialValue = '',
});
```

Source: `lib/src/cron_input.dart`, constructor lines 489–494; field types lines 505–508.

```dart
static CronInput cronInput(
  String label, {
  required CronProfile profile,
  String initialValue = '',
  CronPreviewConfig? preview,
});
```

Source: `lib/src/timezone_select.dart`, constructor lines 6–10.

```dart
static TimezoneSelect timezoneSelect(
  String label, {
  String? defaultValue,
  Map<String, String> unavailable = const {},
});
```

Source: `lib/src/path_input.dart`, constructor lines 8–14; fields following the constructor.

```dart
static PathInput pathInput(
  String label, {
  String? base,
  String initialValue = '',
  bool allowNonexistent = false,
  PathTarget target = PathTarget.any,
});
```

### Filesystem picker parts — 2 classes

Source: `lib/src/filesystem_picker.dart`, constructors lines 5–6 and 28–29; field types lines 7–8 and 30–31.

```dart
static FilePicker filePicker(
  String label, {
  String? base,
});

static DirectoryPicker directoryPicker(
  String label, {
  String? base,
});
```

### Key capture parts — 2 classes

Source: `lib/src/key_capture.dart`, constructors lines 33–35 and 95–97; field types lines 36–37 and 98–99.

```dart
static Keypress keypress(
  String label, {
  bool requireObservation = false,
});

static KeyChordInput keyChordInput(
  String label, {
  bool requireObservation = false,
});
```

### Duration and date parts — 2 classes

Source: `lib/src/duration_input.dart`, constructor lines 19–26; field types lines 38–43.

```dart
static DurationInput durationInput(
  String label, {
  required DurationInputMode durationMode,
  bool signed = false,
  bool allowZero = true,
  int? minimumMicroseconds,
  String? initialValue,
});
```

Source: `lib/src/date_input.dart`, constructor lines 302–309; fields lines 325–330.

```dart
static DateInput dateInput(
  String label, {
  DateOrder? order,
  DateCalendar? calendar,
  DateDigits? digits,
  String? initialValue,
});
```

The `calendar` and `digits` constructor parameters are nullable with implicit `null` defaults. The constructor internally substitutes `DateCalendar.gregorian` and `DateDigits.ascii`; those are **not** parameter defaults and are therefore not substituted into this signature.

### Feedback — 4 classes

Source: `lib/src/feedback.dart`

```dart
// Constructor: line 23; field types: 24–25.
static Text text(
  String content, {
  TextKind kind = TextKind.ordinary,
});

// Constructor: lines 44–49; field types: 55–57.
static Progress progress(
  String label, {
  int? total,
  Duration interval = const Duration(seconds: 5),
  int milestone = 10,
});

// Constructor: line 198; field type: 199.
static Spinner spinner(String label);

// Constructor: lines 271–274; interval field type: 290.
static MultiSpinner multiSpinner(
  Iterable<String> tasks, {
  Duration interval = const Duration(seconds: 5),
});
```

## Inventory boundary and resolution status

- **38 actual implemented classes:** 14 core prompts + 4 suggestion/choice parts + 10 specialized inputs + 2 filesystem pickers + 2 key capture prompts + 2 duration/date prompts + 4 feedback classes.
- **`StepperForm` is prototype-only and excluded.** This distinction is explicitly documented in `doc/theme-components.md:59` and `docs/issues/trelis-theming/issues/03-static-theme-api-and-colours.md:118`.
- No proposed presentation parameters are included.
- No files were edited and no tests were run.
