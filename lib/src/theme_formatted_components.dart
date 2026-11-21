/// Internal, theme-owned formatted-value component family.
///
/// Each instance captures immutable component configuration and binds to one
/// [ThemeSession]. The session resolves interaction and colour before the
/// first output and owns the reader, writer and lifecycle; the real component
/// is delegated to with that session, so no competing reader, second external
/// prompt or invocation-level I/O is introduced. This library is deliberately
/// absent from the public export barrel; the breaking public cutover is a
/// later ticket.
library;

import 'dart:async';

import 'color_resolution.dart' show ColorPreferences, ComponentColors;
import 'color_theme.dart' show ColorTheme;
import 'hint_observations.dart' show NativeHintObservations;
import 'interaction_resolution.dart' show InteractionPreferences;
import 'prompt_structure.dart' show PromptStructure;
import 'state_help_presentation.dart'
    show
        CompactHint,
        ComponentRoute,
        PresentationMode,
        compactHint,
        composePromptPresentation;
import 'terminal_io.dart' show TerminalEnvironment;
import 'text_input.dart'
    show
        CivilDate,
        ColorInput,
        ColorValue,
        CronExpression,
        CronInput,
        CronPreviewConfig,
        CronProfile,
        DateCalendar,
        DateDigits,
        DateFieldOrder,
        DateInput,
        DurationInput,
        DurationInputMode,
        DurationValue,
        EmailInput,
        IPAddressInput,
        IPAddressValue,
        InstructionDisplay,
        MaskInterpretation,
        MaskTemplate,
        MaskedInput,
        MaskedValue,
        NumericAnswer,
        NumericConvention,
        NumberInput,
        PortInput,
        PromptResult,
        RangeSlider,
        Slider,
        TagInput,
        TagStyle,
        TerminalSession,
        TimeInput,
        TimezoneSelect,
        URLInput;
import 'theme_session.dart'
    show
        ThemeFeedbackHandle,
        ThemeInteractionFactsProvider,
        ThemeResolvedCallback,
        ThemeSession,
        ThemeSessionHandle;

/// Which real component a [ThemeFormattedPrompt] delegates to.
enum ThemeFormattedComponent {
  slider,
  rangeSlider,
  number,
  port,
  ipAddress,
  url,
  email,
  color,
  duration,
  cron,
  masked,
  tag,
  date,
  time,
  timezone,
}

/// A reusable prompt from the formatted-value family.
final class ThemeFormattedPrompt<T> {
  ThemeFormattedPrompt._({
    required this.kind,
    required this.label,
    required this._essential,
    required this._create,
    required TerminalEnvironment io,
    this.colors = const ComponentColors(),
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) : _owner = ThemeSession(
         environment: io,
         colors: themeColors,
         interaction: interaction,
         onResolved: onResolved,
         factsForPeriod: factsForPeriod,
         hints: hints,
       );

  /// Exact decimal slider with a fixed lower bound and step.
  static ThemeFormattedPrompt<String> slider(
    String label, {
    required TerminalEnvironment io,
    required String minimum,
    required String maximum,
    required String step,
    String? initialValue,
    int? precision,
    String? units,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<String>._(
    kind: ThemeFormattedComponent.slider,
    label: label,
    essential:
        '$label exact decimal: minimum $minimum, maximum $maximum, '
        'step $step${units == null ? '' : ', units $units'}.',
    create: (palette, session) => Slider(
      label,
      minimum: minimum,
      maximum: maximum,
      step: step,
      initialValue: initialValue,
      precision: precision,
      units: units,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Two exact decimal endpoints kept inside a minimum gap.
  static ThemeFormattedPrompt<(String, String)> rangeSlider(
    String label, {
    required TerminalEnvironment io,
    required String minimum,
    required String maximum,
    required String step,
    String minimumGap = '0',
    String? initialLower,
    String? initialUpper,
    int? precision,
    String? units,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<(String, String)>._(
    kind: ThemeFormattedComponent.rangeSlider,
    label: label,
    essential:
        '$label lower and upper exact decimals: minimum $minimum, '
        'maximum $maximum, step $step, minimum gap $minimumGap.',
    create: (palette, session) => RangeSlider(
      label,
      minimum: minimum,
      maximum: maximum,
      step: step,
      minimumGap: minimumGap,
      initialLower: initialLower,
      initialUpper: initialUpper,
      precision: precision,
      units: units,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Base-ten number entry with a stable numeric convention.
  static ThemeFormattedPrompt<NumericAnswer?> number(
    String label, {
    required TerminalEnvironment io,
    NumericConvention? convention,
    NumericConvention? Function()? conventionProvider,
    bool decimal = false,
    String? minimum,
    String? maximum,
    int? precision,
    bool required = true,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<NumericAnswer?>._(
    kind: ThemeFormattedComponent.number,
    label: label,
    essential: '$label ${decimal ? 'decimal' : 'integer'} numeric entry.',
    create: (palette, session) => NumberInput(
      label,
      convention: convention,
      conventionProvider: conventionProvider,
      decimal: decimal,
      minimum: minimum,
      maximum: maximum,
      precision: precision,
      required: required,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// ASCII decimal port entry within the configured range.
  static ThemeFormattedPrompt<int> port(
    String label, {
    required TerminalEnvironment io,
    bool allowZero = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<int>._(
    kind: ThemeFormattedComponent.port,
    label: label,
    essential: '$label ASCII decimal port, ${allowZero ? 0 : 1} to 65535.',
    create: (palette, session) => PortInput(
      label,
      allowZero: allowZero,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Numeric IP address entry with optional prefix and zone.
  static ThemeFormattedPrompt<IPAddressValue> ipAddress(
    String label, {
    required TerminalEnvironment io,
    bool cidr = false,
    bool scoped = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<IPAddressValue>._(
    kind: ThemeFormattedComponent.ipAddress,
    label: label,
    essential:
        '$label numeric IPv4 or IPv6 address'
        '${cidr ? ' with prefix' : ''}${scoped ? ' and zone' : ''}.',
    create: (palette, session) => IPAddressInput(
      label,
      cidr: cidr,
      scoped: scoped,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Absolute URL entry restricted to the caller's schemes.
  static ThemeFormattedPrompt<String> url(
    String label, {
    required TerminalEnvironment io,
    required Set<String> allowedSchemes,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<String>._(
    kind: ThemeFormattedComponent.url,
    label: label,
    essential:
        '$label absolute URL; allowed schemes '
        '${allowedSchemes.join(', ')}.',
    create: (palette, session) => URLInput(
      label,
      allowedSchemes: allowedSchemes,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Bare SMTP mailbox entry.
  static ThemeFormattedPrompt<String> email(
    String label, {
    required TerminalEnvironment io,
    bool smtpUtf8 = false,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<String>._(
    kind: ThemeFormattedComponent.email,
    label: label,
    essential: '$label bare SMTP address entry.',
    create: (palette, session) => EmailInput(
      label,
      smtpUtf8: smtpUtf8,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// CSS sRGB colour entry with its live textual preview.
  static ThemeFormattedPrompt<ColorValue?> color(
    String label, {
    required TerminalEnvironment io,
    bool required = true,
    String initialValue = '',
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<ColorValue?>._(
    kind: ThemeFormattedComponent.color,
    label: label,
    essential: '$label CSS sRGB colour entry; the preview is textual.',
    create: (palette, session) => ColorInput(
      label,
      required: required,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Elapsed or calendar-relative duration entry.
  static ThemeFormattedPrompt<DurationValue> duration(
    String label, {
    required TerminalEnvironment io,
    required DurationInputMode durationMode,
    bool signed = false,
    bool allowZero = true,
    int? minimumMicroseconds,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<DurationValue>._(
    kind: ThemeFormattedComponent.duration,
    label: label,
    essential:
        '$label '
        '${durationMode == DurationInputMode.elapsed ? 'elapsed' : 'calendar-relative'} '
        'duration entry with a textual interpretation.',
    create: (palette, session) => DurationInput(
      label,
      durationMode: durationMode,
      signed: signed,
      allowZero: allowZero,
      minimumMicroseconds: minimumMicroseconds,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Cron expression entry for one explicitly selected dialect.
  static ThemeFormattedPrompt<CronExpression> cron(
    String label, {
    required TerminalEnvironment io,
    required CronProfile profile,
    String initialValue = '',
    CronPreviewConfig? preview,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<CronExpression>._(
    kind: ThemeFormattedComponent.cron,
    label: label,
    essential: '$label ${profile.name} cron expression entry.',
    create: (palette, session) => CronInput(
      label,
      profile: profile,
      initialValue: initialValue,
      preview: preview,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Template-constrained mask entry with explicit interpretation.
  static ThemeFormattedPrompt<MaskedValue> masked(
    String label, {
    required TerminalEnvironment io,
    required List<MaskTemplate> templates,
    MaskedValue? initialValue,
    MaskInterpretation interpretation = MaskInterpretation.automatic,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<MaskedValue>._(
    kind: ThemeFormattedComponent.masked,
    label: label,
    essential:
        '$label mask entry; templates '
        '${templates.map((template) => template.name).join(', ')}.',
    create: (palette, session) => MaskedInput(
      label,
      templates: templates,
      initialValue: initialValue,
      interpretation: interpretation,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Canonical tag collection with explicit add and finish actions.
  static ThemeFormattedPrompt<List<String>> tag(
    String label, {
    required TerminalEnvironment io,
    TagStyle style = TagStyle.kebabCase,
    int? maxLength,
    String? Function(String)? validate,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<List<String>>._(
    kind: ThemeFormattedComponent.tag,
    label: label,
    essential:
        '$label '
        '${style == TagStyle.snakeCase ? 'snake_case' : 'kebab-case'} tag '
        'collection; draft tags are not accepted until added.',
    create: (palette, session) => TagInput(
      label,
      style: style,
      maxLength: maxLength,
      validate: validate,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Civil date entry in an explicit calendar and field order.
  static ThemeFormattedPrompt<CivilDate> date(
    String label, {
    required TerminalEnvironment io,
    DateFieldOrder? order,
    DateCalendar? calendar,
    DateDigits? digits,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<CivilDate>._(
    kind: ThemeFormattedComponent.date,
    label: label,
    essential: '$label civil date entry in ${order?.name ?? 'system'} order.',
    create: (palette, session) => DateInput(
      label,
      order: order,
      calendar: calendar,
      digits: digits,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// Time-of-day entry with labeled segments in rich interaction.
  static ThemeFormattedPrompt<({int hour, int minute, int? second})> time(
    String label, {
    required TerminalEnvironment io,
    bool twelveHour = false,
    bool seconds = false,
    String? initialValue,
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<({int hour, int minute, int? second})>._(
    kind: ThemeFormattedComponent.time,
    label: label,
    essential:
        '$label time of day, not a date or timezone'
        '${seconds ? ', with seconds' : ''}'
        '${twelveHour ? ', 12-hour clock' : ''}.',
    create: (palette, session) => TimeInput(
      label,
      twelveHour: twelveHour,
      seconds: seconds,
      initialValue: initialValue,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  /// IANA zone identity search with readable unavailable reasons.
  static ThemeFormattedPrompt<String> timezone(
    String label, {
    required TerminalEnvironment io,
    String? defaultValue,
    Map<String, String> unavailable = const {},
    ComponentColors colors = const ComponentColors(),
    PromptStructure structure = PromptStructure.plain,
    InstructionDisplay instructions = InstructionDisplay.themeDefault,
    List<String> supplementaryHelp = const [],
    ColorPreferences themeColors = const ColorPreferences(),
    InteractionPreferences interaction = const InteractionPreferences(),
    ThemeResolvedCallback? onResolved,
    ThemeInteractionFactsProvider? factsForPeriod,
    NativeHintObservations? hints,
  }) => ThemeFormattedPrompt<String>._(
    kind: ThemeFormattedComponent.timezone,
    label: label,
    essential: '$label IANA zone identity search; no offset preview.',
    create: (palette, session) => TimezoneSelect(
      label,
      defaultValue: defaultValue,
      unavailable: unavailable,
      colors: palette,
      structure: structure,
      instructions: instructions,
      supplementaryHelp: supplementaryHelp,
    ).prompt(session: session),
    io: io,
    colors: colors,
    themeColors: themeColors,
    interaction: interaction,
    onResolved: onResolved,
    factsForPeriod: factsForPeriod,
    hints: hints,
  );

  final ThemeFormattedComponent kind;
  final String label;
  final ComponentColors colors;
  final String _essential;
  final Future<PromptResult<T>> Function(
    ColorTheme palette,
    TerminalSession session,
  )
  _create;
  final ThemeSession _owner;

  /// Restoration failures retained after a successful primary operation.
  List<Object> get cleanupFailures => _owner.cleanupFailures;

  /// Runs this component with the period's resolved interaction and palette.
  Future<PromptResult<T>> prompt() => _owner.prompt((handle) async {
    final palette = handle.componentColors(colors).palette;
    final mode = handle.presentationMode;
    if (mode == PresentationMode.screenReader) {
      handle.session.presentText(
        composePromptPresentation(
          mode: mode,
          prompt: label,
          essential: _essential,
          hint: _hint(mode),
        ).essentialBefore!,
      );
    }
    return _create(palette, handle.session);
  });

  /// Starts live feedback that shares this prompt's active period.
  Future<ThemeFeedbackHandle> startFeedback(
    FutureOr<void> Function(ThemeSessionHandle handle) start, {
    required FutureOr<void> Function() stop,
  }) => _owner.startFeedback(start, stop: stop);

  CompactHint _hint(PresentationMode mode) {
    final (primary, short) = switch ((kind, mode)) {
      (ThemeFormattedComponent.slider, PresentationMode.rich) => (
        'Enter activates Edit or Submit',
        'Enter',
      ),
      (ThemeFormattedComponent.slider, _) => (
        'Enter an exact value, then submit',
        'Enter',
      ),
      (ThemeFormattedComponent.rangeSlider, PresentationMode.rich) => (
        'Tab moves between endpoints; Enter submits',
        'Enter',
      ),
      (ThemeFormattedComponent.rangeSlider, _) => (
        'Enter Lower then Upper, then submit',
        'Enter',
      ),
      (_, PresentationMode.rich) => ('Enter edits or submits', 'Enter'),
      _ => ('Enter submits', 'Enter'),
    };
    return compactHint(
      mode: mode,
      component: ComponentRoute.standard,
      primaryAction: primary,
      shortPrimaryAction: short,
    );
  }
}
