/// Verifies the unstable public API from an external package.
///
/// The positive fixture compiles against only `package:trelis/trelis.dart`.
/// Negative snippets are written temporarily inside the fixture package so
/// `dart analyze --format machine` resolves them through the same path
/// dependency, then removed. A negative case passes only when every analyzer
/// error carries one of the case's expected diagnostic codes and at least one
/// expected code was observed, so an unrelated failure cannot pass as a
/// rejection and one hidden symbol cannot hide behind another's error.
library;

import 'dart:io';

final _fixture = Directory('fixtures/public_api_fixture');
final _negativeDir = Directory('fixtures/public_api_fixture/tool');

final class _Case {
  const _Case(this.source, this.expectedCodes);

  final String source;

  /// Machine-format error codes that prove the surface rejected the snippet.
  final Set<String> expectedCodes;
}

_Case _hidden(String name) => _Case(
  '''
import 'package:trelis/trelis.dart';
void main() => print($name);
''',
  {'UNDEFINED_IDENTIFIER'},
);

/// The 34 legacy interactive component classes plus the 4 legacy feedback
/// components: none may be reachable through the public barrel.
const _legacyComponents = <String>[
  'TextInput',
  'Password',
  'Multiline',
  'Confirm',
  'Checkbox',
  'Toggle',
  'Select',
  'Radio',
  'MultiSelect',
  'TreeSelect',
  'SortableSelect',
  'CommandPalette',
  'Autocomplete',
  'SearchSelect',
  'Slider',
  'RangeSlider',
  'NumberInput',
  'PortInput',
  'TimeInput',
  'TagInput',
  'MaskedInput',
  'ColorInput',
  'CronInput',
  'DurationInput',
  'DateInput',
  'TimezoneSelect',
  'IPAddressInput',
  'URLInput',
  'EmailInput',
  'PathInput',
  'FilePicker',
  'DirectoryPicker',
  'Keypress',
  'KeyChordInput',
  'Text',
  'Progress',
  'Spinner',
  'MultiSpinner',
];

/// Internal theme component wrappers and resolver internals that must also
/// stay hidden.
const _internalNames = <String>[
  'ThemeTextPrompt',
  'ThemeBooleanPrompt',
  'ThemeSingleChoicePrompt',
  'ThemeMultiSelectPrompt',
  'ThemeTreeSelectPrompt',
  'ThemeOrderPrompt',
  'ThemeAutocompletePrompt',
  'ThemeSearchPrompt',
  'ThemeFilesystemPrompt',
  'ThemeFormattedPrompt',
  'ThemeKeyCapturePrompt',
  'ThemeSession',
  'TerminalSession',
  'InteractionFacts',
  'InteractionResolution',
  'InteractionConflict',
  'InteractionUnavailable',
  'ColorDetectionFacts',
  'PresentationPreferences',
  'prototypeTextInputPrompt',
  'prototypeSelectPrompt',
];

/// Resolver functions stay internal; hints arrive through theme parameters.
const _resolverFunctions = <String>['resolveInteraction', 'resolveColors'];

_Case _snippet(String body, Set<String> codes) => _Case('''
import 'package:trelis/trelis.dart';
void main() {
  final theme = RailTheme(io: TerminalEnvironment.scripted(
    input: const Stream<String>.empty(), output: StringBuffer()));
$body
}
''', codes);

final _cases = <String, _Case>{
  'direct_constructor': _Case(
    '''
import 'package:trelis/trelis.dart';
void main() {
  final component = TextInput('Name');
  print(component);
}
''',
    {'UNDEFINED_FUNCTION'},
  ),
  'static_factory': _Case(
    '''
import 'package:trelis/trelis.dart';
void main() {
  final component = RailTheme.textInput('Name');
  print(component);
}
''',
    {'UNDEFINED_METHOD'},
  ),
  'supplied_answer': _Case(
    '''
import 'package:trelis/trelis.dart';
void main() => print(SuppliedAnswer('answer'));
''',
    {'UNDEFINED_FUNCTION'},
  ),
  'supplied_tags': _Case(
    '''
import 'package:trelis/trelis.dart';
void main() => print(SuppliedTags(['tag']));
''',
    {'UNDEFINED_FUNCTION'},
  ),
  'invocation_io': _snippet("  print(theme.textInput('Name', source: null));", {
    'UNDEFINED_NAMED_PARAMETER',
  }),
  'invocation_mode': _snippet(
    "  print(theme.confirm('Proceed?', mode: null));",
    {'UNDEFINED_NAMED_PARAMETER'},
  ),
  for (final parameter in [
    'mode',
    'source',
    'terminal',
    'output',
    'outputProfile',
    'presentation',
    'session',
  ])
    'prompt_$parameter': _snippet(
      "  print(theme.textInput('Name').prompt($parameter: null));",
      {'UNDEFINED_NAMED_PARAMETER'},
    ),
  'feedback_present_configuration': _snippet(
    "  print(theme.text('done').present(clock: null));",
    {'UNDEFINED_NAMED_PARAMETER'},
  ),
  'feedback_start_configuration': _snippet(
    "  print(theme.progress('job').start(session: null));",
    {'UNDEFINED_NAMED_PARAMETER'},
  ),
  'theme_close': _snippet("  theme.close();", {'UNDEFINED_METHOD'}),
  for (final name in _legacyComponents) 'hidden_$name': _hidden(name),
  for (final name in _internalNames) 'hidden_$name': _hidden(name),
  for (final name in _resolverFunctions) 'hidden_resolver_$name': _hidden(name),
};

Future<ProcessResult> _analyze(String path) => Process.run('dart', [
  'analyze',
  '--format',
  'machine',
  path,
], workingDirectory: _fixture.path);

void _fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
}

Future<void> main() async {
  if (!_fixture.existsSync()) {
    _fail('Missing ${_fixture.path}.');
    return;
  }
  var get = await Process.run('dart', [
    'pub',
    'get',
    '--offline',
  ], workingDirectory: _fixture.path);
  if (get.exitCode != 0) {
    _fail('Fixture pub get failed:\n${get.stdout}\n${get.stderr}');
    return;
  }
  var positive = await Process.run('dart', [
    'analyze',
    'bin/positive.dart',
  ], workingDirectory: _fixture.path);
  if (positive.exitCode != 0) {
    _fail('Positive fixture failed:\n${positive.stdout}\n${positive.stderr}');
    return;
  }
  stdout.writeln('positive fixture: ok');

  await _negativeDir.create(recursive: true);
  for (final entry in _cases.entries) {
    final relative = 'tool/${entry.key}.dart';
    final file = File('${_negativeDir.path}/${entry.key}.dart');
    await file.writeAsString(entry.value.source);
    try {
      final result = await _analyze(relative);
      final output = '${result.stdout}\n${result.stderr}';
      final observed = <String>{};
      final unexpected = <String>[];
      for (final line in output.split('\n')) {
        final fields = line.split('|');
        if (fields.length < 4 || fields[0] != 'ERROR') continue;
        final code = fields[2];
        if (entry.value.expectedCodes.contains(code)) {
          observed.add(code);
        } else {
          unexpected.add(line);
        }
      }
      if (observed.isEmpty) {
        _fail(
          '${entry.key}: no expected diagnostic '
          '${entry.value.expectedCodes} in output:\n$output',
        );
      } else if (unexpected.isNotEmpty) {
        _fail(
          '${entry.key}: unexpected analyzer errors:\n'
          '${unexpected.join('\n')}\nfull output:\n$output',
        );
      } else {
        stdout.writeln('${entry.key}: rejected (${observed.join(', ')})');
      }
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }
  if (exitCode == 0) stdout.writeln('negative public API inventory: ok');
}
