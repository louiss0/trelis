import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

/// Smoke tests for the exported surface: every component must be constructible
/// through `package:trelis/trelis.dart` alone, and the shared session seam
/// must be usable through it.
void main() {
  test('the public library exposes all 38 components', () {
    final components = <Object>[
      TextInput('Name'),
      Password('Secret'),
      Multiline('Notes'),
      Autocomplete('Name', suggestions: (_) async => const ['Ada']),
      TagInput('Tags'),
      Confirm('Deploy?'),
      Checkbox('Accept'),
      Toggle('Cache'),
      Select<String>('Choice', [Choice('a', 'First')]),
      Radio<String>('Choice', [Choice('a', 'First')]),
      MultiSelect<String>('Choices', [Choice('a', 'First')]),
      SearchSelect('Fruit', [Choice('a', 'Apple')]),
      CommandPalette('Commands', [Choice('save', 'Save')]),
      TimezoneSelect('Zone'),
      TreeSelect<String>('Tree', [TreeNode('a', 'A')]),
      SortableSelect<String>('Order', [Choice('a', 'First')]),
      Slider('Volume', minimum: '0', maximum: '1', step: '0.2'),
      RangeSlider('Window', minimum: '0', maximum: '10', step: '1'),
      TimeInput('Time'),
      PathInput('Path', allowNonexistent: true),
      FilePicker('File'),
      DirectoryPicker('Directory'),
      Keypress('Shortcut'),
      KeyChordInput('Sequence'),
      NumberInput('Count', convention: NumericConvention.ascii()),
      PortInput('Port'),
      IPAddressInput('Address'),
      URLInput('URL', allowedSchemes: {'https'}),
      EmailInput('Email'),
      ColorInput('Color'),
      MaskedInput(
        'Code',
        templates: [
          MaskTemplate('code', [
            MaskSlot('digit', (value) => '0123456789'.contains(value)),
          ]),
        ],
      ),
      DurationInput('Span', durationMode: DurationInputMode.elapsed),
      DateInput('Date', order: DateFieldOrder.dayMonthYear),
      CronInput('Schedule', profile: CronProfile.unix),
      Text('Hello'),
      Progress('Work', total: 1),
      Spinner('Work'),
      MultiSpinner(['build', 'test']),
    ];
    expect(components, hasLength(38));
    expect(
      components.map((component) => component.runtimeType).toSet(),
      hasLength(38),
    );
  });

  test('a scripted linear session returns a documented outcome', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', initialValue: 'alpha').prompt(
      source: ScriptedInput(Stream.value('\x7f\x7f\x7f\x7f\x7fbeta\r'), output),
      mode: PromptMode.linear,
    );
    expect(result, isA<Accepted<String>>());
    expect((result as Accepted<String>).value, 'beta');
    expect(output.toString(), contains('Name'));
  });
}
