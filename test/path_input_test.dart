import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('supplied literal prospective path retains dot segments and shell characters', () async {
    final base = Directory.current.path;
    final value = 'folder${path.separator}..${path.separator}\$HOME';
    final result = await PathInput(
      'Path',
      base: base,
      allowNonexistent: true,
    ).prompt(source: SuppliedAnswer(value));
    expect((result as Accepted<String>).value, '$base${path.separator}$value');
  });
  test('linear cancellation and input end never accept', () async {
    for (final entry in ['/cancel\r', 'partial']) {
      final result = await PathInput('Path', allowNonexistent: true).prompt(
        source: ScriptedInput(Stream.value(entry), StringBuffer()),
        mode: PromptMode.linear,
      );
      expect(
        result,
        entry.startsWith('/')
            ? isA<Cancelled<String>>()
            : isA<InputEnded<String>>(),
      );
    }
  });
  test('review can return to draft without accepting', () async {
    final out = StringBuffer();
    final base = Directory.current.path;
    final result =
        await PathInput(
          'Path',
          base: base,
          allowNonexistent: true,
          initialValue: 'first',
        ).prompt(
          source: ScriptedInput(
            Stream.value('\redit\r\x7f\x7f\x7f\x7f\x7fsecond\r\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, '$base${path.separator}second');
    expect(
      out.toString(),
      contains('Resolved candidate: $base${path.separator}first'),
    );
  });
  test('Windows UNC quoting preserves both leading backslashes', () async {
    if (!Platform.isWindows) return;
    final out = StringBuffer();
    final result = await PathInput('Path', allowNonexistent: true).prompt(
      source: ScriptedInput(
        Stream.value(
          r'\\\server\share\folder'
          '\r\r',
        ),
        out,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, r'\\server\share\folder');
  });
  test('initial command-shaped literal remains data when reopened', () async {
    final out = StringBuffer();
    final result =
        await PathInput(
          'Path',
          initialValue: '/cancel',
          allowNonexistent: true,
        ).prompt(
          source: ScriptedInput(Stream.value('\r\r'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Accepted<String>>());
  });
  test('literal spaces and shell punctuation are not expanded', () async {
    final base = Directory.current.path;
    const value = r'~ $HOME "quoted" *';
    final result = await PathInput(
      'Path',
      base: base,
      allowNonexistent: true,
    ).prompt(source: SuppliedAnswer(value));
    expect((result as Accepted<String>).value, '$base${path.separator}$value');
  });
}
