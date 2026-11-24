import 'dart:async';

import 'package:trelis/src/color_theme.dart';
import 'package:trelis/src/feedback.dart';
import 'package:trelis/src/prompt_structure.dart';
import 'package:trelis/src/text_input.dart';

/// Round-theme factory namespace.
///
/// Components created through these factories are configured with [PromptStructure.round].
///
/// Every method returns a configured instance of an existing component. The
/// factory does not invoke [prompt], [present] or [start]; call those on the
/// returned object with the desired session/profile configuration.
abstract final class RoundTheme {
  static TextInput textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => TextInput(
    label,
    initialValue: initialValue,
    required: required,
    validate: validate,
    maxLength: maxLength,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Password password(
    String label, {
    String initialValue = '',
    bool mask = false,
    bool required = false,
    String? Function(String)? validate,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Password(
    label,
    initialValue: initialValue,
    mask: mask,
    required: required,
    validate: validate,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Confirm confirm(
    String label, {
    bool initialValue = false,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Confirm(
    label,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Checkbox checkbox(
    String label, {
    bool initialValue = false,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Checkbox(
    label,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Toggle toggle(
    String label, {
    bool initialValue = false,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Toggle(
    label,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Multiline multiline(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Multiline(
    label,
    initialValue: initialValue,
    required: required,
    validate: validate,
    maxLength: maxLength,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Select<T> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Select<T>(
    label,
    choices,
    defaultValue: defaultValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Radio<T> radio<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Radio<T>(
    label,
    choices,
    defaultValue: defaultValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static MultiSelect<T> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => MultiSelect<T>(
    label,
    choices,
    defaultValues: defaultValues,
    min: min,
    max: max,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

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
  }) => Slider(
    label,
    minimum: minimum,
    maximum: maximum,
    step: step,
    initialValue: initialValue,
    precision: precision,
    units: units,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

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
  }) => RangeSlider(
    label,
    minimum: minimum,
    maximum: maximum,
    step: step,
    minimumGap: minimumGap,
    initialLower: initialLower,
    initialUpper: initialUpper,
    precision: precision,
    units: units,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static TreeSelect<T> treeSelect<T>(
    String label,
    List<TreeNode<T>> nodes, {
    bool Function(T value)? isCurrent,
    T? defaultValue,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => TreeSelect<T>(
    label,
    nodes,
    isCurrent: isCurrent,
    defaultValue: defaultValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static TimeInput timeInput(
    String label, {
    bool twelveHour = false,
    bool seconds = false,
    String? initialValue,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => TimeInput(
    label,
    twelveHour: twelveHour,
    seconds: seconds,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static TagInput tagInput(
    String label, {
    TagStyle style = TagStyle.kebabCase,
    int? maxLength,
    String? Function(String)? validate,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => TagInput(
    label,
    style: style,
    maxLength: maxLength,
    validate: validate,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

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
  }) => Autocomplete(
    label,
    suggestions: suggestions,
    initialValue: initialValue,
    required: required,
    validate: validate,
    maxLength: maxLength,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static SearchSelect<T> searchSelect<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    FutureOr<List<Choice<T>>> Function(String query)? search,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => SearchSelect<T>(
    label,
    choices,
    defaultValue: defaultValue,
    search: search,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static SortableSelect<T> sortableSelect<T>(
    String label,
    List<Choice<T>> choices, {
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => SortableSelect<T>(
    label,
    choices,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static MaskedInput maskedInput(
    String label, {
    required List<MaskTemplate> templates,
    MaskedValue? initialValue,
    MaskInterpretation interpretation = MaskInterpretation.automatic,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => MaskedInput(
    label,
    templates: templates,
    initialValue: initialValue,
    interpretation: interpretation,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

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
  }) => NumberInput(
    label,
    convention: convention,
    conventionProvider: conventionProvider,
    decimal: decimal,
    minimum: minimum,
    maximum: maximum,
    precision: precision,
    required: required,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static PortInput portInput(
    String label, {
    bool allowZero = false,
    String initialValue = '',
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => PortInput(
    label,
    allowZero: allowZero,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static IPAddressInput ipAddressInput(
    String label, {
    bool cidr = false,
    bool scoped = false,
    String initialValue = '',
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => IPAddressInput(
    label,
    cidr: cidr,
    scoped: scoped,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static URLInput urlInput(
    String label, {
    required Set<String> allowedSchemes,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => URLInput(
    label,
    allowedSchemes: allowedSchemes,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static EmailInput emailInput(
    String label, {
    bool smtpUtf8 = false,
    String initialValue = '',
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => EmailInput(
    label,
    smtpUtf8: smtpUtf8,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static ColorInput colorInput(
    String label, {
    bool required = true,
    String initialValue = '',
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => ColorInput(
    label,
    required: required,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static CronInput cronInput(
    String label, {
    required CronProfile profile,
    String initialValue = '',
    CronPreviewConfig? preview,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    CronCellFrame cellFrame = CronCellFrame.square,
    List<String> supplementaryHelp = const [],
  }) => CronInput(
    label,
    profile: profile,
    initialValue: initialValue,
    preview: preview,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    cellFrame: cellFrame,
    supplementaryHelp: supplementaryHelp,
  );

  static TimezoneSelect timezoneSelect(
    String label, {
    String? defaultValue,
    Map<String, String> unavailable = const {},
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => TimezoneSelect(
    label,
    defaultValue: defaultValue,
    unavailable: unavailable,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static PathInput pathInput(
    String label, {
    String? base,
    String initialValue = '',
    bool allowNonexistent = false,
    PathTarget target = PathTarget.any,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => PathInput(
    label,
    base: base,
    initialValue: initialValue,
    allowNonexistent: allowNonexistent,
    target: target,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static FilePicker filePicker(
    String label, {
    String? base,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => FilePicker(
    label,
    base: base,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static DirectoryPicker directoryPicker(
    String label, {
    String? base,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => DirectoryPicker(
    label,
    base: base,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Keypress keypress(
    String label, {
    bool requireObservation = false,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Keypress(
    label,
    requireObservation: requireObservation,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Keybind<List<String>> keybind(
    String label, {
    List<String> modifiers = Keybind.defaultModifiers,
    List<String> symbols = Keybind.defaultSymbols,
    List<String> initialValue = const [],
    CronCellFrame cellFrame = CronCellFrame.square,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Keybind<List<String>>(
    label,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    cellFrame: cellFrame,
    structure: PromptStructure.round,
    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Keybind<String> joinedKeybind(
    String label, {
    List<String> modifiers = Keybind.defaultModifiers,
    List<String> symbols = Keybind.defaultSymbols,
    List<String> initialValue = const [],
    CronCellFrame cellFrame = CronCellFrame.square,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => Keybind<String>.joined(
    label,
    modifiers: modifiers,
    symbols: symbols,
    initialValue: initialValue,
    cellFrame: cellFrame,
    structure: PromptStructure.round,
    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

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
  }) => DurationInput(
    label,
    durationMode: durationMode,
    signed: signed,
    allowZero: allowZero,
    minimumMicroseconds: minimumMicroseconds,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static DateInput dateInput(
    String label, {
    DateFieldOrder? order,
    DateCalendar? calendar,
    DateDigits? digits,
    String? initialValue,
    ColorTheme colors = ColorThemes.terminalDefault,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => DateInput(
    label,
    order: order,
    calendar: calendar,
    digits: digits,
    initialValue: initialValue,
    structure: PromptStructure.round,

    colors: colors,
    instructions: instructions,
    supplementaryHelp: supplementaryHelp,
  );

  static Text text(
    String content, {
    TextKind kind = TextKind.ordinary,
    ColorTheme colors = ColorThemes.terminalDefault,
  }) => Text(
    content,
    kind: kind,
    colors: colors,
    structure: PromptStructure.round,
  );

  static Progress progress(
    String label, {
    int? total,
    Duration interval = const Duration(seconds: 5),
    int milestone = 10,
    ColorTheme colors = ColorThemes.terminalDefault,
  }) => Progress(
    label,
    total: total,
    interval: interval,
    milestone: milestone,
    structure: PromptStructure.round,

    colors: colors,
  );

  static Spinner spinner(
    String label, {
    ColorTheme colors = ColorThemes.terminalDefault,
  }) => Spinner(label, colors: colors, structure: PromptStructure.round);

  static MultiSpinner multiSpinner(
    Iterable<String> tasks, {
    Duration interval = const Duration(seconds: 5),
    ColorTheme colors = ColorThemes.terminalDefault,
  }) => MultiSpinner(
    tasks,
    interval: interval,
    colors: colors,
    structure: PromptStructure.round,
  );
}
