import 'package:trelis/src/testing/compat_api.dart';

/// One public component's real render/task path for a structural theme.
///
/// The matrix is the whole public interactive surface (34 components), not a
/// family sample: a structure that frames one choice list but not another is a
/// defect this matrix has to catch. A case supplies display input for both
/// interaction modes and, where a component's linear command set differs from
/// its rich key set, the rich spelling separately.
class ThemeMatrixCase {
  const ThemeMatrixCase(
    this.name,
    this.label,
    this.answer,
    this.run, {
    this.richAnswer,
    this.outcome,
  });

  /// The component name, used as the test name.
  final String name;

  /// The label the component must present as its stage heading.
  final String label;

  /// Input that completes the task in linear output.
  final String answer;

  /// Input that completes the task in rich output, when it differs.
  final String? richAnswer;

  /// A reported outcome or notice that must be presented outside a closed
  /// frame, never swallowed as a body row of a frame left open.
  final String? outcome;

  /// Runs the component's real task against [input] and returns its result.
  final Future<Object?> Function(
    PromptMode mode,
    ScriptedInput input,
    PromptStructure structure,
  )
  run;

  /// The input spelling this case needs in [mode].
  String answerFor(PromptMode mode) =>
      mode == PromptMode.rich ? (richAnswer ?? answer) : answer;
}

/// The interactive components, each with a real render/task path per structure
/// and mode.
///
/// The case table is shared by the per-ticket framing suites and the
/// consolidated theme matrix, so a new component or a new structure is added
/// once and both proofs cover it. [pickerBase] is read when a case runs, not
/// when the table is built, because the fixture directory is created in
/// `setUpAll`.
List<ThemeMatrixCase> themeMatrixCases({
  required String Function() pickerBase,
}) => [
  ThemeMatrixCase(
    'TextInput',
    'Deployment target',
    'Ada\r',
    (mode, input, structure) => TextInput(
      'Deployment target',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'Password',
    'Passphrase',
    'secret\rsubmit\r',
    (mode, input, structure) => Password(
      'Passphrase',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'Confirm',
    'Decision',
    'yes\r',
    (mode, input, structure) => Confirm(
      'Decision',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
    outcome: 'Accepted: Yes.',
  ),
  ThemeMatrixCase(
    'Checkbox',
    'Terms',
    'yes\r',
    (mode, input, structure) => Checkbox(
      'Terms',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  ThemeMatrixCase(
    'Toggle',
    'Cache',
    'yes\r',
    (mode, input, structure) =>
        Toggle('Cache', structure: structure).prompt(source: input, mode: mode),
    richAnswer: 'y\r',
  ),
  ThemeMatrixCase(
    'Multiline',
    'Notes',
    'abc\r/done\r',
    (mode, input, structure) => Multiline(
      'Notes',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'abc\t\r',
  ),
  ThemeMatrixCase(
    'Select',
    'Choice',
    '2\r',
    (mode, input, structure) => Select<String>('Choice', [
      Choice('a', 'First'),
      Choice('b', 'Second'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
    outcome: 'Accepted: Second.',
  ),
  ThemeMatrixCase(
    'Radio',
    'Signal',
    '2\r',
    (mode, input, structure) => Radio<String>('Signal', [
      Choice('a', 'Red'),
      Choice('b', 'Green'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\r',
    outcome: 'Accepted: Green.',
  ),
  ThemeMatrixCase(
    'MultiSelect',
    'Choices',
    '2\r1\r/done\r',
    (mode, input, structure) => MultiSelect<String>('Choices', [
      Choice('a', 'Alpha'),
      Choice('b', 'Beta'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B \x1b[A \r',
    outcome: 'Beta: checked.',
  ),
  ThemeMatrixCase(
    'Slider',
    'Volume',
    '\x7f\x7f\x7f0.6\r',
    (mode, input, structure) => Slider(
      'Volume',
      minimum: '0',
      maximum: '1',
      step: '0.2',
      initialValue: '0.4',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\t\r',
  ),
  ThemeMatrixCase(
    'RangeSlider',
    'Window',
    '\x7f2\r\x7f8\r\r',
    (mode, input, structure) => RangeSlider(
      'Window',
      minimum: '0',
      maximum: '10',
      step: '1',
      initialLower: '3',
      initialUpper: '5',
      minimumGap: '2',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[C\t\x1b[C\t\t\t\r',
  ),
  ThemeMatrixCase(
    'TreeSelect',
    'Tree',
    '/choose\r2\r',
    (mode, input, structure) => TreeSelect<String>(
      'Tree',
      [TreeNode('a', 'A'), TreeNode('b', 'B')],
      defaultValue: 'b',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\r',
    outcome: 'Accepted: B.',
  ),
  ThemeMatrixCase(
    'SortableSelect',
    'Order',
    '/move\r2\r1\r/done\r',
    (mode, input, structure) => SortableSelect<String>('Order', [
      Choice('a', 'A'),
      Choice('b', 'B'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: ' \x1b[B\r\r',
    outcome: 'moved to position ',
  ),
  ThemeMatrixCase(
    'TimeInput',
    'Time',
    '\r',
    (mode, input, structure) => TimeInput(
      'Time',
      initialValue: '23:59',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '+\t+\t\t\r',
  ),
  ThemeMatrixCase(
    'TagInput',
    'Tags',
    'NewTag\r/done\r',
    (mode, input, structure) => TagInput(
      'Tags',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'NewTag\r\t\r',
  ),
  ThemeMatrixCase(
    'Autocomplete',
    'Suggestion',
    'A\r1\r/submit\r',
    (mode, input, structure) => Autocomplete(
      'Suggestion',
      suggestions: (_) => ['Ada'],
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'A\x1b[B\r\r',
  ),
  ThemeMatrixCase(
    'SearchSelect',
    'Fruit',
    '\r1\r',
    (mode, input, structure) => SearchSelect<String>('Fruit', [
      Choice('a', 'Apple'),
    ], structure: structure).prompt(source: input, mode: mode),
    richAnswer: '\r\r',
  ),

  ThemeMatrixCase(
    'TimezoneSelect',
    'Zone',
    'US/Eastern\r105\r',
    (mode, input, structure) => TimezoneSelect(
      'Zone',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'US/Eastern\r\r',
  ),
  ThemeMatrixCase(
    'MaskedInput',
    'Code',
    '/value\r\x7f3\r/done\r',
    (mode, input, structure) => MaskedInput(
      'Code',
      templates: [
        MaskTemplate('code', [
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
          MaskLiteral('-'),
          MaskSlot('digit', (s) => '0123456789'.contains(s)),
        ]),
      ],
      initialValue: MaskedValue('code', ['1', '2'], '1-2'),
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x7f3\r',
  ),
  ThemeMatrixCase(
    'NumberInput',
    'Count',
    '12\r',
    (mode, input, structure) => NumberInput(
      'Count',
      convention: NumericConvention.ascii(),
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'PortInput',
    'Port',
    '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
    (mode, input, structure) => PortInput(
      'Port',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'IPAddressInput',
    'Address',
    '192.0.2.7/24\r',
    (mode, input, structure) => IPAddressInput(
      'Address',
      cidr: true,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'URLInput',
    'URL',
    'https://example.com/\r',
    (mode, input, structure) => URLInput(
      'URL',
      allowedSchemes: {'https'},
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'EmailInput',
    'Email',
    'Case@example.com\r',
    (mode, input, structure) => EmailInput(
      'Email',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'ColorInput',
    'Colour',
    '\r',
    (mode, input, structure) => ColorInput(
      'Colour',
      initialValue: '#fff',
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'DurationInput',
    'Span',
    '1s\r',
    (mode, input, structure) => DurationInput(
      'Span',
      durationMode: DurationInputMode.elapsed,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'DateInput',
    'Date',
    '29/02/2024\r/submit\r',
    (mode, input, structure) => DateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'CronInput',
    'Schedule',
    '* * * * *\r/submit\r',
    (mode, input, structure) => CronInput(
      'Schedule',
      profile: CronProfile.unix,
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '*\t*\t*\t*\t*\r',
  ),
  ThemeMatrixCase(
    'PathInput',
    'Path',
    '\r\r',
    (mode, input, structure) => PathInput(
      'Path',
      initialValue: 'draft',
      allowNonexistent: true,
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'FilePicker',
    'Workspace',
    'choose 1\r\r',
    (mode, input, structure) => FilePicker(
      'Workspace',
      base: pickerBase(),
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'DirectoryPicker',
    'Workspace',
    'choose\r\r',
    (mode, input, structure) => DirectoryPicker(
      'Workspace',
      base: pickerBase(),
      structure: structure,
    ).prompt(source: input, mode: mode),
  ),
  ThemeMatrixCase(
    'Keypress',
    'Shortcut',
    '/capture\ra/done\r',
    (mode, input, structure) => Keypress(
      'Shortcut',
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: 'ca\r',
  ),
  ThemeMatrixCase(
    'Keybind',
    'Sequence',
    'Ctrl,B\r',
    (mode, input, structure) => Keybind<List<String>>(
      'Sequence',
      symbols: const ['A', 'B'],
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\t\x1b[B\x1b[B\r',
  ),
  ThemeMatrixCase(
    'JoinedKeybind',
    'Sequence',
    'Ctrl,B\r',
    (mode, input, structure) => Keybind<String>.joined(
      'Sequence',
      symbols: const ['A', 'B'],
      structure: structure,
    ).prompt(source: input, mode: mode),
    richAnswer: '\x1b[B\t\x1b[B\x1b[B\r',
  ),
];
