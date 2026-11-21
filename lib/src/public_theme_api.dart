/// Unstable public theme-instance API for the coordinated cutover.
///
/// A theme owns one [TerminalEnvironment] and one lazy active period. Its
/// component methods create reusable prompts or feedback participants; there
/// is no public close, invocation-level I/O or per-prompt presentation
/// configuration. Return types and result types stay public, while concrete
/// component construction remains internal. This signature cutover is not an
/// accessibility qualification.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'color_resolution.dart'
    show ColorPreferences, ComponentColors, ThemePaletteDefaults;
import 'feedback.dart' show FeedbackClock, FeedbackOutcome, TextKind;
import 'hint_observations.dart' show NativeHintObservations;
import 'interaction_resolution.dart' show InteractionPreferences;
import 'prompt_structure.dart' show PromptStructure;
import 'state_help_presentation.dart' show SingleSelectionStyle;
import 'terminal_io.dart'
    show
        TerminalEnvironment,
        TerminalIo,
        TerminalLease,
        TerminalOwnershipIdentity;
import 'text_input.dart'
    show
        Choice,
        CivilDate,
        ColorValue,
        CronExpression,
        CronPreviewConfig,
        CronProfile,
        DateCalendar,
        DateDigits,
        DateFieldOrder,
        DurationInputMode,
        DurationValue,
        IPAddressValue,
        InstructionDisplay,
        KeyGesture,
        MaskInterpretation,
        MaskTemplate,
        MaskedValue,
        NumericAnswer,
        NumericConvention,
        PathTarget,
        PromptResult,
        TagStyle,
        TreeNode;
import 'theme_choice_components.dart'
    show
        ThemeBooleanPrompt,
        ThemeChoiceOption,
        ThemeMultiSelectPrompt,
        ThemeSingleChoicePrompt;
import 'theme_feedback_tracer.dart'
    show ThemeFeedbackControl, ThemeFeedbackTracer;
import 'theme_filesystem_components.dart' show ThemeFilesystemPrompt;
import 'theme_formatted_components.dart' show ThemeFormattedPrompt;
import 'theme_key_capture_components.dart' show ThemeKeyCapturePrompt;
import 'theme_session.dart' show ThemeResolvedCallback, ThemeSession;
import 'theme_text_components.dart' show ThemeTextPrompt;
import 'theme_tree_search_components.dart'
    show
        ThemeAutocompletePrompt,
        ThemeOrderPrompt,
        ThemeSearchPrompt,
        ThemeTreeSelectPrompt;

/// A reusable prompt created by a theme.
///
/// Runs start from the component's configured initial value. Calling [prompt]
/// while the same prompt is already active is rejected by the owning theme.
final class ThemePrompt<T> {
  const ThemePrompt._(this._runner, {required this.structure});

  final Future<PromptResult<T>> Function() _runner;

  /// The fixed structural grammar of the creating theme.
  final PromptStructure structure;

  /// Starts one prompt invocation without runtime configuration.
  Future<PromptResult<T>> prompt() => _runner();
}

/// One-shot theme-owned feedback.
final class ThemeFeedback {
  const ThemeFeedback._(this._present, {required this.structure});

  final Future<void> Function() _present;
  final PromptStructure structure;

  /// Presents one line after the active period has resolved.
  Future<void> present() => _present();
}

/// A live feedback participant started by a theme.
final class ThemeLiveFeedback {
  const ThemeLiveFeedback._(this._start, {required this.structure});

  final Future<ThemeLiveFeedbackControl> Function() _start;
  final PromptStructure structure;

  /// Starts presentation and joins the theme's current active period.
  Future<ThemeLiveFeedbackControl> start() => _start();
}

/// Explicit completion or cancellation of live feedback.
///
/// There is no public theme close: finishing the last participant restores
/// the terminal automatically.
final class ThemeLiveFeedbackControl {
  ThemeLiveFeedbackControl._(this._control);

  final ThemeFeedbackControl<dynamic> _control;

  /// Ends feedback with an explicit outcome.
  Future<void> finish(FeedbackOutcome outcome, {String? detail}) =>
      _control.finish(outcome, detail: detail);

  /// Stops presentation without inventing an outcome.
  Future<void> stop() => _control.stop();
}

/// A minimal default native environment.
///
/// Applications that need precise native input handling should supply a
/// [TerminalEnvironment] explicitly. This default provides a best-effort
/// stdin/stdout binding without claiming native terminal qualification.
final class _NativeThemeAdapter
    implements TerminalIo, TerminalOwnershipIdentity {
  late final Stream<String> _input = stdin.transform(utf8.decoder);

  @override
  Stream<String> get input => _input;

  @override
  StringSink get output => stdout;

  @override
  bool get supportsRich => stdout.hasTerminal;

  @override
  Map<String, String?> get environment => Platform.environment;

  @override
  Object get ownershipIdentity => stdout;

  @override
  TerminalLease acquire() {
    bool? echo;
    bool? line;
    try {
      echo = stdin.echoMode;
      stdin.echoMode = false;
    } catch (_) {
      echo = null;
    }
    try {
      line = stdin.lineMode;
      stdin.lineMode = false;
    } catch (_) {
      line = null;
    }
    return TerminalLease(() {
      if (line != null) {
        try {
          stdin.lineMode = line;
        } catch (_) {}
      }
      if (echo != null) {
        try {
          stdin.echoMode = echo;
        } catch (_) {}
      }
    });
  }
}

final TerminalEnvironment _defaultThemeEnvironment = TerminalEnvironment.custom(
  adapter: _NativeThemeAdapter(),
  profile: TerminalEnvironment.nativeProfile(
    hasTerminal: stdout.hasTerminal,
    supportsRich: stdout.hasTerminal,
    term: Platform.environment['TERM'] ?? '',
  ),
);

/// Shared behavior of the 15 structural theme instances.
///
/// The constructor captures application-level configuration once. Component
/// methods accept only component-scoped overrides; `.prompt()` and feedback
/// entry points take no runtime configuration.
abstract class StructuralTheme {
  StructuralTheme({
    TerminalEnvironment? io,
    this.structure = PromptStructure.plain,
    ThemePaletteDefaults? palettes,
    this.interaction = const InteractionPreferences(),
    this.colors = const ColorPreferences(),
    this.selectionStyle = SingleSelectionStyle.circles,
    this.onResolved,
    this.hints,
  }) : _io = io ?? _defaultThemeEnvironment,
       _owner = ThemeSession(
         environment: io ?? _defaultThemeEnvironment,
         palettes: palettes,
         interaction: interaction,
         colors: colors,
         onResolved: onResolved,
         hints: hints,
       );

  final TerminalEnvironment _io;
  final PromptStructure structure;
  final ThemeSession _owner;

  /// The immutable application interaction preferences.
  final InteractionPreferences interaction;

  /// The immutable application colour preferences.
  final ColorPreferences colors;

  /// The application's single-selection symbol style.
  final SingleSelectionStyle selectionStyle;

  /// Invoked at most once after a successful resolution in each active period.
  final ThemeResolvedCallback? onResolved;

  /// Injectable native/application hint observations.
  final NativeHintObservations? hints;

  /// Cleanup failures observed after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  ThemePrompt<T> _prompt<T>(Future<PromptResult<T>> Function() runner) =>
      ThemePrompt<T>._(runner, structure: structure);

  ThemeFeedback _feedback(Future<void> Function() present) =>
      ThemeFeedback._(present, structure: structure);

  ThemeLiveFeedback _live(
    Future<ThemeFeedbackControl<dynamic>> Function() start,
  ) => ThemeLiveFeedback._(
    () async => ThemeLiveFeedbackControl._(await start()),
    structure: structure,
  );

  // Text, secret and multiline.

  ThemePrompt<String> textInput(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeTextPrompt.text(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> password(
    String label, {
    String initialValue = '',
    bool mask = false,
    bool required = false,
    String? Function(String)? validate,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeTextPrompt.secret(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      mask: mask,
      required: required,
      validate: validate,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> multiline(
    String label, {
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeTextPrompt.multiline(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Boolean and basic choices.

  ThemePrompt<bool> confirm(
    String label, {
    bool initialValue = false,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeBooleanPrompt.confirm(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<bool> checkbox(
    String label, {
    bool initialValue = false,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeBooleanPrompt.checkbox(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<bool> toggle(
    String label, {
    bool initialValue = false,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeBooleanPrompt.toggle(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  List<ThemeChoiceOption<T>> _options<T>(List<Choice<T>> choices) => [
    for (final choice in choices)
      ThemeChoiceOption<T>(
        choice.value,
        choice.label,
        unavailableReason: choice.disabledReason,
      ),
  ];

  ThemePrompt<T> select<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeSingleChoicePrompt<T>.select(
      label,
      _options(choices),
      io: _io,
      session: _owner,
      structure: structure,
      defaultValue: defaultValue,
      selectionStyle: selectionStyle,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<T> radio<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeSingleChoicePrompt<T>.radio(
      label,
      _options(choices),
      io: _io,
      session: _owner,
      structure: structure,
      defaultValue: defaultValue,
      selectionStyle: selectionStyle,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<List<T>> multiSelect<T>(
    String label,
    List<Choice<T>> choices, {
    List<T> defaultValues = const [],
    int min = 0,
    int? max,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeMultiSelectPrompt<T>(
      label,
      _options(choices),
      io: _io,
      session: _owner,
      structure: structure,
      initialSelection: defaultValues,
      min: min,
      max: max,
      selectionStyle: selectionStyle,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Tree, ordering and search.

  ThemePrompt<T> treeSelect<T>(
    String label,
    List<TreeNode<T>> nodes, {
    bool Function(T value)? isCurrent,
    T? defaultValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeTreeSelectPrompt<T>(
      label,
      nodes,
      io: _io,
      session: _owner,
      structure: structure,
      defaultValue: defaultValue,
      isCurrent: isCurrent,
      selectionStyle: selectionStyle,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<List<T>> sortableSelect<T>(
    String label,
    List<Choice<T>> choices, {
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeOrderPrompt<T>(
      label,
      choices,
      io: _io,
      session: _owner,
      structure: structure,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> autocomplete(
    String label, {
    required FutureOr<List<String>> Function(String) suggestions,
    String initialValue = '',
    bool required = false,
    String? Function(String)? validate,
    int? maxLength,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeAutocompletePrompt(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      suggestions: suggestions,
      initialValue: initialValue,
      required: required,
      validate: validate,
      maxLength: maxLength,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<T> searchSelect<T>(
    String label,
    List<Choice<T>> choices, {
    T? defaultValue,
    FutureOr<List<Choice<T>>> Function(String query)? search,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeSearchPrompt<T>.search(
      label,
      choices,
      io: _io,
      session: _owner,
      structure: structure,
      search: search,
      defaultValue: defaultValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<T> commandPalette<T>(
    String label,
    List<Choice<T>> commands, {
    T? defaultValue,
    FutureOr<List<Choice<T>>> Function(String query)? search,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeSearchPrompt<T>.commandPalette(
      label,
      commands,
      io: _io,
      session: _owner,
      structure: structure,
      search: search,
      defaultValue: defaultValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Formatted values.

  ThemePrompt<String> slider(
    String label, {
    required String minimum,
    required String maximum,
    required String step,
    String? initialValue,
    int? precision,
    String? units,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.slider(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      minimum: minimum,
      maximum: maximum,
      step: step,
      initialValue: initialValue,
      precision: precision,
      units: units,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<(String, String)> rangeSlider(
    String label, {
    required String minimum,
    required String maximum,
    required String step,
    String minimumGap = '0',
    String? initialLower,
    String? initialUpper,
    int? precision,
    String? units,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.rangeSlider(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      minimum: minimum,
      maximum: maximum,
      step: step,
      minimumGap: minimumGap,
      initialLower: initialLower,
      initialUpper: initialUpper,
      precision: precision,
      units: units,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<NumericAnswer?> numberInput(
    String label, {
    NumericConvention? convention,
    NumericConvention? Function()? conventionProvider,
    bool decimal = false,
    String? minimum,
    String? maximum,
    int? precision,
    bool required = true,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.number(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      convention: convention,
      conventionProvider: conventionProvider,
      decimal: decimal,
      minimum: minimum,
      maximum: maximum,
      precision: precision,
      required: required,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<int> portInput(
    String label, {
    bool allowZero = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.port(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      allowZero: allowZero,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<({int hour, int minute, int? second})> timeInput(
    String label, {
    bool twelveHour = false,
    bool seconds = false,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.time(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      twelveHour: twelveHour,
      seconds: seconds,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<List<String>> tagInput(
    String label, {
    TagStyle style = TagStyle.kebabCase,
    int? maxLength,
    String? Function(String)? validate,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.tag(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      style: style,
      maxLength: maxLength,
      validate: validate,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<MaskedValue> maskedInput(
    String label, {
    required List<MaskTemplate> templates,
    MaskedValue? initialValue,
    MaskInterpretation interpretation = MaskInterpretation.automatic,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.masked(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      templates: templates,
      initialValue: initialValue,
      interpretation: interpretation,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<ColorValue?> colorInput(
    String label, {
    bool required = true,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.color(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      required: required,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<CronExpression> cronInput(
    String label, {
    required CronProfile profile,
    String initialValue = '',
    CronPreviewConfig? preview,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.cron(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      profile: profile,
      initialValue: initialValue,
      preview: preview,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<DurationValue> durationInput(
    String label, {
    required DurationInputMode durationMode,
    bool signed = false,
    bool allowZero = true,
    int? minimumMicroseconds,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.duration(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      durationMode: durationMode,
      signed: signed,
      allowZero: allowZero,
      minimumMicroseconds: minimumMicroseconds,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<CivilDate> dateInput(
    String label, {
    DateFieldOrder? order,
    DateCalendar? calendar,
    DateDigits? digits,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.date(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      order: order,
      calendar: calendar,
      digits: digits,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> timezoneSelect(
    String label, {
    String? defaultValue,
    Map<String, String> unavailable = const {},
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFormattedPrompt.timezone(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      defaultValue: defaultValue,
      unavailable: unavailable,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Filesystem and network.

  ThemePrompt<IPAddressValue> ipAddressInput(
    String label, {
    bool cidr = false,
    bool scoped = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.ipAddress(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      cidr: cidr,
      scoped: scoped,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> urlInput(
    String label, {
    required Set<String> allowedSchemes,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.url(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      allowedSchemes: allowedSchemes,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> emailInput(
    String label, {
    bool smtpUtf8 = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.email(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      smtpUtf8: smtpUtf8,
      initialValue: initialValue,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> pathInput(
    String label, {
    String? base,
    String initialValue = '',
    bool allowNonexistent = false,
    PathTarget target = PathTarget.any,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.path(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      base: base,
      initialValue: initialValue,
      allowNonexistent: allowNonexistent,
      target: target,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> filePicker(
    String label, {
    String? base,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.filePicker(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      base: base,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<String> directoryPicker(
    String label, {
    String? base,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeFilesystemPrompt.directoryPicker(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      base: base,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Key capture.

  ThemePrompt<KeyGesture> keypress(
    String label, {
    bool requireObservation = false,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeKeyCapturePrompt.keypress(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      requireObservation: requireObservation,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  ThemePrompt<List<KeyGesture>> keyChordInput(
    String label, {
    bool requireObservation = false,
    ComponentColors colors = const ComponentColors(),
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
  }) => _prompt(
    () => ThemeKeyCapturePrompt.keyChordInput(
      label,
      io: _io,
      session: _owner,
      structure: structure,
      requireObservation: requireObservation,
      colors: colors,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(),
  );

  // Feedback.

  ThemeFeedback text(
    String content, {
    TextKind kind = TextKind.ordinary,
    ComponentColors colors = const ComponentColors(),
  }) {
    final feedback = ThemeFeedbackTracer(
      _owner,
      structure: structure,
      colors: colors,
    );
    return _feedback(() => feedback.text(content, kind: kind));
  }

  ThemeLiveFeedback progress(
    String label, {
    int? total,
    Duration interval = const Duration(seconds: 5),
    int milestone = 10,
    FeedbackClock? clock,
    ComponentColors colors = const ComponentColors(),
  }) {
    final feedback = ThemeFeedbackTracer(
      _owner,
      structure: structure,
      colors: colors,
    );
    return _live(() async {
      return feedback.progress(
        label,
        total: total,
        interval: interval,
        milestone: milestone,
        clock: clock,
      );
    });
  }

  ThemeLiveFeedback spinner(
    String label, {
    ComponentColors colors = const ComponentColors(),
  }) {
    final feedback = ThemeFeedbackTracer(
      _owner,
      structure: structure,
      colors: colors,
    );
    return _live(() async {
      return feedback.spinner(label);
    });
  }

  ThemeLiveFeedback multiSpinner(
    Iterable<String> tasks, {
    Duration interval = const Duration(seconds: 5),
    FeedbackClock? clock,
    ComponentColors colors = const ComponentColors(),
  }) {
    final feedback = ThemeFeedbackTracer(
      _owner,
      structure: structure,
      colors: colors,
    );
    return _live(() async {
      return feedback.multiSpinner(tasks, interval: interval, clock: clock);
    });
  }
}
