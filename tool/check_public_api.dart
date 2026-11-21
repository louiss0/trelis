/// Verifies the unstable public API from an external package.
///
/// The positive fixture compiles against only `package:trelis/trelis.dart`.
/// Negative snippets are written temporarily inside the fixture package so
/// `dart analyze` resolves them through the same path dependency, then removed.
/// A negative case passes only when analysis reports the expected error kind.
library;

import 'dart:io';

final _fixture = Directory('fixtures/public_api_fixture');
final _negativeDir = Directory('fixtures/public_api_fixture/tool');

const _cases = <String, String>{
  'direct_constructor': '''
import 'package:trelis/trelis.dart';
void main() {
  final component = TextInput('Name');
  print(component);
}
''',
  'static_factory': '''
import 'package:trelis/trelis.dart';
void main() {
  final component = RailTheme.textInput('Name');
  print(component);
}
''',
  'supplied_answer': '''
import 'package:trelis/trelis.dart';
void main() => print(SuppliedAnswer('answer'));
''',
  'supplied_tags': '''
import 'package:trelis/trelis.dart';
void main() => print(SuppliedTags(['tag']));
''',
  'invocation_io': '''
import 'package:trelis/trelis.dart';
void main() {
  final theme = RailTheme(io: TerminalEnvironment.scripted(
    input: const Stream<String>.empty(), output: StringBuffer()));
  print(theme.textInput('Name', source: null));
}
''',
  'invocation_mode': '''
import 'package:trelis/trelis.dart';
void main() {
  final theme = RailTheme(io: TerminalEnvironment.scripted(
    input: const Stream<String>.empty(), output: StringBuffer()));
  print(theme.confirm('Proceed?', mode: null));
}
''',
  'prompt_configuration': '''
import 'package:trelis/trelis.dart';
void main() {
  final theme = RailTheme(io: TerminalEnvironment.scripted(
    input: const Stream<String>.empty(), output: StringBuffer()));
  print(theme.textInput('Name').prompt(session: null));
}
''',
};

Future<ProcessResult> _analyze(String path) =>
    Process.run('dart', ['analyze', path], workingDirectory: _fixture.path);

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
    await file.writeAsString(entry.value);
    try {
      final result = await _analyze(relative);
      final output = '${result.stdout}\n${result.stderr}';
      if (result.exitCode == 0) {
        _fail('${entry.key}: expected an analyzer error, got success.');
      } else if (!output.contains('error -')) {
        _fail('${entry.key}: analyzer failed without an error:\n$output');
      } else {
        stdout.writeln('${entry.key}: rejected');
      }
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }
  if (exitCode == 0) stdout.writeln('negative public API inventory: ok');
}
