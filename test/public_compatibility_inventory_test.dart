import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

/// Compile- and source-level checks of the public compatibility inventory.
///
/// The approved baseline is `docs/issues/trelis-theming/api-baseline.md`. Every
/// constructor below supplies the baseline parameters with non-default values
/// plus the intentional migrations this backend added (instruction display,
/// supplementary help and a component palette where the component supports
/// one), so a renamed, removed or narrowed parameter fails to compile here.
///
/// Invocation is checked by binding each component's `prompt` tear-off to the
/// shared signature. The binding checks the documented named parameters and
/// preserves each component's answer type; it does not run a prompt.
typedef PromptInvocation<T> = Future<PromptResult<T>> Function({
  PromptSource? source,
  PromptMode? mode,
  PromptMode? userPreference,
  PromptMode? applicationPreference,
  Stdout? output,
  TerminalIo? terminal,
  OutputProfile? outputProfile,
  TerminalSession? session,
});

typedef FeedbackStart = void Function({
  StringSink? output,
  TerminalIo? terminal,
  PromptMode? mode,
  PromptMode? userPreference,
  PromptMode? applicationPreference,
  bool? supportsRich,
  TerminalSession? session,
});

typedef TextPresentation = void Function({
  StringSink? output,
  TerminalIo? terminal,
  TerminalSession? session,
});

/// A complete palette distinct from [ColorThemes.terminalDefault].
final _palette = ColorTheme(
  foreground: TerminalColor.rgb(200, 200, 200),
  background: TerminalColor.rgb(16, 16, 16),
  muted: TerminalColor.indexed(244),
  accent: TerminalColor.indexed(75),
  selectionForeground: TerminalColor.indexed(16),
  selectionBackground: TerminalColor.indexed(75),
  success: TerminalColor.indexed(34),
  warning: TerminalColor.indexed(178),
  error: TerminalColor.indexed(160),
  border: TerminalColor.indexed(240),
);

final _mask = MaskTemplate('code', [
  MaskSlot('digit', (value) => '0123456789'.contains(value)),
]);

CronPreviewConfig _preview() => CronPreviewConfig(
  zone: 'UTC',
  reference: DateTime.utc(2024, 4, 1, 12),
  start: DateTime.utc(2024, 4, 1),
  end: DateTime.utc(2024, 4, 2),
  count: 3,
  budget: 100,
  providerTimeout: const Duration(milliseconds: 500),
);

/// The 34 interactive components, constructed through the baseline inventory.
List<Object> _interactive() => [
  TextInput(
    'Name',
    initialValue: 'alpha',
    required: true,
    validate: (value) => value.isEmpty ? 'required' : null,
    maxLength: 5,
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  Password(
    'Secret',
    initialValue: 'prefill',
    mask: true,
    required: true,
    validate: (value) => value.isEmpty ? 'required' : null,
  ),
  Multiline(
    'Notes',
    initialValue: 'one',
    required: true,
    validate: (value) => value.isEmpty ? 'required' : null,
    maxLength: 10,
  ),
  Autocomplete(
    'Name',
    suggestions: (_) async => const ['Ada'],
    initialValue: 'A',
    required: true,
    validate: (value) => value.isEmpty ? 'required' : null,
    maxLength: 20,
    instructions: InstructionDisplay.expanded,
    supplementaryHelp: const ['Application context.'],
  ),
  TagInput(
    'Tags',
    style: TagStyle.snakeCase,
    maxLength: 12,
    validate: (value) => value.isEmpty ? 'required' : null,
  ),
  Confirm('Deploy?', initialValue: true, colors: _palette),
  Checkbox('Accept', initialValue: true, colors: _palette),
  Toggle('Cache', initialValue: true, colors: _palette),
  Select<int>(
    'Choice',
    [Choice(1, 'First')],
    defaultValue: 1,
    colors: _palette,
  ),
  Radio<int>('Choice', [Choice(1, 'First')], defaultValue: 1, colors: _palette),
  MultiSelect<int>(
    'Choices',
    [Choice(1, 'First')],
    defaultValues: const [1],
    min: 1,
    max: 2,
    colors: _palette,
  ),
  SearchSelect<int>(
    'Fruit',
    [Choice(1, 'Apple')],
    defaultValue: 1,
    search: (_) async => [Choice(1, 'Apple')],
    instructions: InstructionDisplay.themeDefault,
    supplementaryHelp: const ['Application context.'],
  ),
  CommandPalette<int>(
    'Commands',
    [Choice(1, 'Save')],
    defaultValue: 1,
    search: (_) async => [Choice(1, 'Save')],
    instructions: InstructionDisplay.hidden,
    supplementaryHelp: const ['Application context.'],
  ),
  TimezoneSelect(
    'Zone',
    defaultValue: 'UTC',
    unavailable: const {'Pacific/Kiritimati': 'Unavailable in this fixture.'},
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
  ),
  TreeSelect<int>(
    'Tree',
    [TreeNode(1, 'A')],
    isCurrent: (value) => value == 1,
    defaultValue: 1,
    colors: _palette,
  ),
  SortableSelect<int>('Order', [Choice(1, 'First')], colors: _palette),
  Slider(
    'Volume',
    minimum: '0',
    maximum: '10',
    step: '1',
    initialValue: '5',
    precision: 0,
    units: 'dB',
  ),
  RangeSlider(
    'Window',
    minimum: '0',
    maximum: '10',
    step: '1',
    minimumGap: '1',
    initialLower: '1',
    initialUpper: '9',
    precision: 0,
    units: 's',
  ),
  TimeInput(
    'Time',
    twelveHour: true,
    seconds: true,
    initialValue: '01:02:03 PM',
  ),
  PathInput(
    'Path',
    base: Directory.current.path,
    initialValue: '.',
    allowNonexistent: true,
    target: PathTarget.directory,
    colors: _palette,
  ),
  FilePicker('File', base: Directory.current.path, colors: _palette),
  DirectoryPicker('Directory', base: Directory.current.path, colors: _palette),
  Keypress('Shortcut', requireObservation: true),
  KeyChordInput('Sequence', requireObservation: true),
  NumberInput(
    'Count',
    convention: NumericConvention.ascii(),
    conventionProvider: NumericConvention.ascii,
    decimal: true,
    minimum: '0',
    maximum: '10',
    precision: 2,
    required: false,
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  PortInput(
    'Port',
    allowZero: true,
    initialValue: '8080',
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  IPAddressInput(
    'Address',
    cidr: false,
    scoped: true,
    initialValue: 'fe80::1%eth0',
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  URLInput('URL', allowedSchemes: const {'http', 'https'}),
  EmailInput(
    'Email',
    smtpUtf8: true,
    initialValue: 'a@b.example',
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  ColorInput(
    'Color',
    required: false,
    initialValue: '#ff0000',
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  MaskedInput(
    'Code',
    templates: [_mask],
    initialValue: MaskedValue('code', const ['1'], '1'),
    interpretation: MaskInterpretation.formatted,
  ),
  DurationInput(
    'Span',
    durationMode: DurationInputMode.elapsed,
    signed: true,
    allowZero: false,
    minimumMicroseconds: 1,
    initialValue: '1s',
    instructions: InstructionDisplay.compact,
    supplementaryHelp: const ['Application context.'],
    colors: _palette,
  ),
  DateInput(
    'Date',
    order: DateFieldOrder.dayMonthYear,
    calendar: DateCalendar.gregorian,
    digits: DateDigits.ascii,
    initialValue: '01/02/2024',
  ),
  CronInput(
    'Schedule',
    profile: CronProfile.unix,
    initialValue: '* * * * *',
    preview: _preview(),
  ),
];

/// The four feedback components, constructed through the baseline inventory.
List<Object> _feedback() => [
  Text('Hello', kind: TextKind.warning),
  Progress(
    'Work',
    total: 10,
    interval: const Duration(seconds: 1),
    milestone: 5,
  ),
  Spinner('Work'),
  MultiSpinner(const ['build', 'test'], interval: const Duration(seconds: 1)),
];

void main() {
  group('public authoring surface', () {
    test('the barrel exports only the documented implementation libraries', () {
      final exports = File('lib/prompty.dart')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.startsWith('export '))
          .toList();

      expect(
        exports,
        [
          "export 'src/text_input.dart';",
          "export 'src/feedback.dart';",
          "export 'src/output_profile.dart';",
          "export 'src/color_theme.dart';",
          "export 'src/prompt_structure.dart';",
          "export 'src/terminal_io.dart';",
          "export 'src/themes/plain_theme.dart';",
          "export 'src/themes/rail_theme.dart';",
          "export 'src/themes/branch_theme.dart';",
          "export 'src/themes/box_theme.dart';",
          "export 'src/themes/round_theme.dart';",
          "export 'src/themes/double_theme.dart';",
          "export 'src/themes/minimal_theme.dart';",
          "export 'src/themes/ascii_theme.dart';",
          "export 'src/themes/chevron_theme.dart';",
          "export 'src/themes/bracket_theme.dart';",
          "export 'src/themes/form_theme.dart';",
          "export 'src/themes/ledger_theme.dart';",
          "export 'src/themes/colon_theme.dart';",
        ],
        reason:
            'The presentation projection, layout and compositor stay internal: '
            'they are observed through the public transcript, not authored by '
            'library consumers. The structural vocabulary enum and theme '
            'factory namespaces are public authoring surface and are exported '
            'alongside the component libraries.',
      );
    });
  });

  group('constructor compatibility', () {
    test('the 34 interactive components keep their inventory constructor', () {
      final components = _interactive();
      expect(components, hasLength(34));
      expect(
        components.map((component) => component.runtimeType).toSet(),
        hasLength(34),
      );
    });

    test('the four feedback components keep their inventory constructor', () {
      final components = _feedback();
      expect(components, hasLength(4));
      expect(
        components.map((component) => component.runtimeType).toSet(),
        hasLength(4),
      );
    });

    test('baseline generic types and nullable answers are preserved', () {
      final selection = Select<int>('Choice', [Choice(1, 'First')]);
      final int? defaultSelection = selection.defaultValue;
      expect(defaultSelection, isNull);
      expect(selection.choices.single.value, 1);

      final order = SortableSelect<int>('Order', [Choice(1, 'First')]);
      expect(order.choices.single.value, 1);

      final number = NumberInput('Count');
      expect(number.convention, isNull);
      final nullableColor = ColorInput('Color', required: false);
      expect(nullableColor.required, isFalse);
    });
  });

  group('invocation compatibility', () {
    test('every interactive component keeps the shared invocation seam', () {
      final invocations = <String, PromptInvocation<Object?>>{
        'TextInput': TextInput('Name').prompt,
        'Password': Password('Secret').prompt,
        'Multiline': Multiline('Notes').prompt,
        'Autocomplete': Autocomplete('A', suggestions: (_) => ['Ada']).prompt,
        'TagInput': TagInput('Tags').prompt,
        'Confirm': Confirm('Deploy?').prompt,
        'Checkbox': Checkbox('Accept').prompt,
        'Toggle': Toggle('Cache').prompt,
        'Select': Select<int>('Choice', [Choice(1, 'First')]).prompt,
        'Radio': Radio<int>('Choice', [Choice(1, 'First')]).prompt,
        'MultiSelect': MultiSelect<int>('Choices', [Choice(1, 'First')]).prompt,
        'SearchSelect': SearchSelect<int>('Fruit', [Choice(1, 'Apple')]).prompt,
        'CommandPalette': CommandPalette<int>('Commands', [
          Choice(1, 'Save'),
        ]).prompt,
        'TimezoneSelect': TimezoneSelect('Zone').prompt,
        'TreeSelect': TreeSelect<int>('Tree', [TreeNode(1, 'A')]).prompt,
        'SortableSelect': SortableSelect<int>('Order', [
          Choice(1, 'First'),
        ]).prompt,
        'Slider': Slider(
          'Volume',
          minimum: '0',
          maximum: '10',
          step: '1',
        ).prompt,
        'RangeSlider': RangeSlider(
          'Window',
          minimum: '0',
          maximum: '10',
          step: '1',
        ).prompt,
        'TimeInput': TimeInput('Time').prompt,
        'PathInput': PathInput('Path').prompt,
        'FilePicker': FilePicker('File').prompt,
        'DirectoryPicker': DirectoryPicker('Directory').prompt,
        'Keypress': Keypress('Shortcut').prompt,
        'KeyChordInput': KeyChordInput('Sequence').prompt,
        'NumberInput': NumberInput('Count').prompt,
        'PortInput': PortInput('Port').prompt,
        'IPAddressInput': IPAddressInput('Address').prompt,
        'URLInput': URLInput('URL', allowedSchemes: const {'https'}).prompt,
        'EmailInput': EmailInput('Email').prompt,
        'ColorInput': ColorInput('Color').prompt,
        'MaskedInput': MaskedInput('Code', templates: [_mask]).prompt,
        'DurationInput': DurationInput(
          'Span',
          durationMode: DurationInputMode.elapsed,
        ).prompt,
        'DateInput': DateInput('Date').prompt,
        'CronInput': CronInput('Schedule', profile: CronProfile.unix).prompt,
      };

      expect(invocations, hasLength(34));
    });

    test('every component keeps its documented answer type', () {
      final PromptInvocation<String> textInput = TextInput('Name').prompt;
      final PromptInvocation<String> password = Password('Secret').prompt;
      final PromptInvocation<String> multiline = Multiline('Notes').prompt;
      final PromptInvocation<String> autocomplete = Autocomplete(
        'A',
        suggestions: (_) => ['Ada'],
      ).prompt;
      final PromptInvocation<List<String>> tagInput = TagInput('Tags').prompt;
      final PromptInvocation<bool> confirm = Confirm('Deploy?').prompt;
      final PromptInvocation<bool> checkbox = Checkbox('Accept').prompt;
      final PromptInvocation<bool> toggle = Toggle('Cache').prompt;
      final PromptInvocation<int> select = Select<int>('Choice', [
        Choice(1, 'First'),
      ]).prompt;
      final PromptInvocation<int> radio = Radio<int>('Choice', [
        Choice(1, 'First'),
      ]).prompt;
      final PromptInvocation<List<int>> multiSelect = MultiSelect<int>(
        'Choices',
        [Choice(1, 'First')],
      ).prompt;
      final PromptInvocation<int> searchSelect = SearchSelect<int>('Fruit', [
        Choice(1, 'Apple'),
      ]).prompt;
      final PromptInvocation<int> commandPalette = CommandPalette<int>(
        'Commands',
        [Choice(1, 'Save')],
      ).prompt;
      final PromptInvocation<String> timezoneSelect = TimezoneSelect('Zone')
          .prompt;
      final PromptInvocation<int> treeSelect = TreeSelect<int>('Tree', [
        TreeNode(1, 'A'),
      ]).prompt;
      final PromptInvocation<List<int>> sortableSelect = SortableSelect<int>(
        'Order',
        [Choice(1, 'First')],
      ).prompt;
      final PromptInvocation<String> slider = Slider(
        'Volume',
        minimum: '0',
        maximum: '10',
        step: '1',
      ).prompt;
      final PromptInvocation<(String, String)> rangeSlider = RangeSlider(
        'Window',
        minimum: '0',
        maximum: '10',
        step: '1',
      ).prompt;
      final PromptInvocation<({int hour, int minute, int? second})> timeInput =
          TimeInput('Time').prompt;
      final PromptInvocation<String> pathInput = PathInput('Path').prompt;
      final PromptInvocation<String> filePicker = FilePicker('File').prompt;
      final PromptInvocation<String> directoryPicker = DirectoryPicker(
        'Directory',
      ).prompt;
      final PromptInvocation<KeyGesture> keypress = Keypress('Shortcut').prompt;
      final PromptInvocation<List<KeyGesture>> keyChord = KeyChordInput(
        'Sequence',
      ).prompt;
      final PromptInvocation<NumericAnswer?> numberInput = NumberInput('Count')
          .prompt;
      final PromptInvocation<int> portInput = PortInput('Port').prompt;
      final PromptInvocation<IPAddressValue> ipAddress = IPAddressInput(
        'Address',
      ).prompt;
      final PromptInvocation<String> urlInput = URLInput(
        'URL',
        allowedSchemes: const {'https'},
      ).prompt;
      final PromptInvocation<String> emailInput = EmailInput('Email').prompt;
      final PromptInvocation<ColorValue?> colorInput = ColorInput('Color')
          .prompt;
      final PromptInvocation<MaskedValue> maskedInput = MaskedInput(
        'Code',
        templates: [_mask],
      ).prompt;
      final PromptInvocation<DurationValue> durationInput = DurationInput(
        'Span',
        durationMode: DurationInputMode.elapsed,
      ).prompt;
      final PromptInvocation<CivilDate> dateInput = DateInput('Date').prompt;
      final PromptInvocation<CronExpression> cronInput = CronInput(
        'Schedule',
        profile: CronProfile.unix,
      ).prompt;

      expect([
        textInput,
        password,
        multiline,
        autocomplete,
        tagInput,
        confirm,
        checkbox,
        toggle,
        select,
        radio,
        multiSelect,
        searchSelect,
        commandPalette,
        timezoneSelect,
        treeSelect,
        sortableSelect,
        slider,
        rangeSlider,
        timeInput,
        pathInput,
        filePicker,
        directoryPicker,
        keypress,
        keyChord,
        numberInput,
        portInput,
        ipAddress,
        urlInput,
        emailInput,
        colorInput,
        maskedInput,
        durationInput,
        dateInput,
        cronInput,
      ], hasLength(34));
    });

    test('every feedback component keeps its live-region invocation', () {
      final FeedbackStart progress = Progress('Work', total: 10).start;
      final FeedbackStart spinner = Spinner('Work').start;
      final FeedbackStart multiSpinner = MultiSpinner(const ['build']).start;
      final TextPresentation text = Text('Hello').present;

      expect([progress, spinner, multiSpinner, text], hasLength(4));
    });
  });

  group('documented defaults', () {
    test('baseline constructor defaults are unchanged', () {
      expect(Password('Secret').mask, isFalse);
      expect(Password('Secret').required, isFalse);
      expect(Multiline('Notes').required, isFalse);
      expect(Confirm('Deploy?').initialValue, isFalse);
      expect(Checkbox('Accept').initialValue, isFalse);
      expect(Toggle('Cache').initialValue, isFalse);
      expect(PortInput('Port').allowZero, isFalse);
      expect(IPAddressInput('Address').cidr, isFalse);
      expect(IPAddressInput('Address').scoped, isFalse);
      expect(EmailInput('Email').smtpUtf8, isFalse);
      expect(ColorInput('Color').required, isTrue);
      expect(NumberInput('Count').required, isTrue);
      expect(NumberInput('Count').decimal, isFalse);
      expect(Keypress('Shortcut').requireObservation, isFalse);
      expect(KeyChordInput('Sequence').requireObservation, isFalse);
      expect(DateInput('Date').calendar, DateCalendar.gregorian);
      expect(DateInput('Date').digits, DateDigits.ascii);
      expect(TimeInput('Time').twelveHour, isFalse);
      expect(TimeInput('Time').seconds, isFalse);
      expect(
        DurationInput(
          'Span',
          durationMode: DurationInputMode.elapsed,
        ).allowZero,
        isTrue,
      );
      expect(
        DurationInput('Span', durationMode: DurationInputMode.elapsed).signed,
        isFalse,
      );
      expect(PathInput('Path').allowNonexistent, isFalse);
      expect(PathInput('Path').target, PathTarget.any);
      expect(
        MaskedInput('Code', templates: [_mask]).interpretation,
        MaskInterpretation.automatic,
      );
      expect(TagInput('Tags').style, TagStyle.kebabCase);
    });
  });
}
