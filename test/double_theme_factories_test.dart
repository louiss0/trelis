import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// Public instance factory template. `tool/generate_theme_tests.py` rewrites
/// this file for the other 14 structural themes; do not edit those targets.
DoubleTheme _theme() => DoubleTheme(
  io: TerminalEnvironment.scripted(
    input: const Stream<String>.empty(),
    output: StringBuffer(),
  ),
);

void main() {
  group('DoubleTheme typed factories', () {
    test('text, secret and multiline return reusable prompts', () {
      final theme = _theme();
      expect(theme.textInput('Name'), isA<ThemePrompt<String>>());
      expect(theme.password('Token'), isA<ThemePrompt<String>>());
      expect(theme.multiline('Notes'), isA<ThemePrompt<String>>());
      expect(theme.textInput('Name').structure, PromptStructure.double);
    });

    test('boolean and choice families preserve answer types', () {
      final theme = _theme();
      final choices = [Choice('a', 'Alpha'), Choice('b', 'Beta')];
      expect(theme.confirm('Proceed?'), isA<ThemePrompt<bool>>());
      expect(theme.checkbox('Accept'), isA<ThemePrompt<bool>>());
      expect(theme.toggle('Enable'), isA<ThemePrompt<bool>>());
      expect(
        theme.select<String>('Choice', choices),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.radio<String>('Choice', choices),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.multiSelect<String>('Choices', choices),
        isA<ThemePrompt<List<String>>>(),
      );
    });

    test('tree, ordering and search families preserve answer types', () {
      final theme = _theme();
      final choices = [Choice('a', 'Alpha')];
      expect(
        theme.treeSelect<String>('Node', [TreeNode('a', 'Alpha')]),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.sortableSelect<String>('Order', choices),
        isA<ThemePrompt<List<String>>>(),
      );
      expect(
        theme.autocomplete('Package', suggestions: (_) async => const ['Ada']),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.searchSelect<String>('Find', choices),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.commandPalette<String>('Run', choices),
        isA<ThemePrompt<String>>(),
      );
    });

    test('formatted and configured families return prompts', () {
      final theme = _theme();
      expect(
        theme.slider('Volume', minimum: '0', maximum: '10', step: '1'),
        isA<ThemePrompt<String>>(),
      );
      expect(
        theme.rangeSlider('Range', minimum: '0', maximum: '10', step: '1'),
        isA<ThemePrompt<(String, String)>>(),
      );
      expect(
        theme.timeInput('Time'),
        isA<ThemePrompt<({int hour, int minute, int? second})>>(),
      );
      expect(theme.tagInput('Tags'), isA<ThemePrompt<List<String>>>());
      expect(
        theme.autocomplete('Package', suggestions: (_) async => const []),
        isA<ThemePrompt<String>>(),
      );
      expect(theme.numberInput('Count'), isA<ThemePrompt<NumericAnswer?>>());
      expect(
        theme.maskedInput(
          'Code',
          templates: [
            MaskTemplate('hex', [
              MaskSlot(
                'hex digit',
                (s) => RegExp(r'^[0-9a-fA-F]$').hasMatch(s),
              ),
            ]),
          ],
        ),
        isA<ThemePrompt<MaskedValue>>(),
      );
      expect(theme.colorInput('Color'), isA<ThemePrompt<ColorValue?>>());
      expect(
        theme.cronInput('Schedule', profile: CronProfile.unix),
        isA<ThemePrompt<CronExpression>>(),
      );
      expect(
        theme.durationInput('Span', durationMode: DurationInputMode.elapsed),
        isA<ThemePrompt<DurationValue>>(),
      );
      expect(theme.dateInput('Date'), isA<ThemePrompt<CivilDate>>());
      expect(theme.timezoneSelect('Zone'), isA<ThemePrompt<String>>());
      expect(theme.portInput('Port'), isA<ThemePrompt<int>>());
      expect(
        theme.ipAddressInput('Address'),
        isA<ThemePrompt<IPAddressValue>>(),
      );
      expect(
        theme.urlInput('URL', allowedSchemes: const {'https'}),
        isA<ThemePrompt<String>>(),
      );
      expect(theme.emailInput('Email'), isA<ThemePrompt<String>>());
    });

    test('filesystem, key capture and feedback families return handles', () {
      final theme = _theme();
      expect(theme.pathInput('Path'), isA<ThemePrompt<String>>());
      expect(theme.filePicker('File'), isA<ThemePrompt<String>>());
      expect(theme.directoryPicker('Directory'), isA<ThemePrompt<String>>());
      expect(theme.keypress('Shortcut'), isA<ThemePrompt<KeyGesture>>());
      expect(
        theme.keyChordInput('Sequence'),
        isA<ThemePrompt<List<KeyGesture>>>(),
      );
      expect(theme.text('Done'), isA<ThemeFeedback>());
      expect(theme.progress('Work'), isA<ThemeLiveFeedback>());
      expect(theme.spinner('Work'), isA<ThemeLiveFeedback>());
      expect(theme.multiSpinner(['build', 'test']), isA<ThemeLiveFeedback>());
    });

    test('component overrides cannot change invocation configuration', () {
      final theme = _theme();
      final prompt = theme.textInput(
        'Name',
        colors: ComponentColors.palette(ColorThemes.signal),
        instructions: InstructionDisplay.compact,
        supplementaryHelp: const ['Application context.'],
      );
      expect(prompt, isA<ThemePrompt<String>>());
      expect(prompt.structure, PromptStructure.double);
    });
  });
}
