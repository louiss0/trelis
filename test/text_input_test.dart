import 'dart:async';
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('a supplied answer is accepted without interpreting commands', () async {
    final result = await TextInput('Name').prompt(source: SuppliedAnswer('/cancel'));
    expect((result as Accepted<String>).value, '/cancel');
  });
  test('linear scripted entry submits a complete line', () async {
    final output = StringBuffer();
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(Stream.value('Ada\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), contains('Name'));
  });
  test('default is editable and required validation keeps the draft', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', initialValue: 'ab', required: true).prompt(
      source: ScriptedInput(Stream.value('\x01\x1b[3~\x1b[3~\rZ\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'Z');
    expect(output.toString(), contains('Required'));
  });  test('linear cancel, quoted commands, and incomplete EOF are distinct', () async {
    Future<PromptResult<String>> run(String keys) => TextInput('Name').prompt(
      source: ScriptedInput(Stream.value(keys), StringBuffer()), mode: PromptMode.linear);
    expect(await run('/cancel\r'), isA<Cancelled<String>>());
    expect((await run('\\/cancel\r') as Accepted<String>).value, '/cancel');
    expect(await run('/cancel'), isA<InputEnded<String>>());
  });  test('validation retains the invalid draft for correction', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', validate: (value) => value == 'abc' ? null : 'Enter abc').prompt(
      source: ScriptedInput(Stream.value('ab\rc\r'), output), mode: PromptMode.linear);
    expect((result as Accepted<String>).value, 'abc');
    expect(output.toString(), contains('Enter abc'));
  });  test('explicit rich mode fails before writing when output lacks capability', () async {
    final output = StringBuffer();
    final source = ScriptedInput(Stream.value('ok\r'), output, supportsRich: false);
    final result = await TextInput('Name').prompt(source: source, mode: PromptMode.rich);
    expect(result, isA<Unavailable<String>>());
    expect(output.toString(), isEmpty);
  });  test('oversized paste is rejected atomically', () async {
    final output = StringBuffer();
    final result = await TextInput('Name', maxLength: 3).prompt(
      source: ScriptedInput(Stream.value('a\x1b[200~bcd\x1b[201~\r'), output), mode: PromptMode.rich);
    expect((result as Accepted<String>).value, 'a');
    expect(output.toString(), contains('limit'));
  });  test('sessions cannot overlap and a completed instance can be reused', () async {
    final input = StreamController<String>();
    final prompt = TextInput('Name');
    final pending = prompt.prompt(source: ScriptedInput(input.stream, StringBuffer()));
    await expectLater(prompt.prompt(source: SuppliedAnswer('x')), throwsStateError);
    input.add('one\r');
    expect((await pending as Accepted<String>).value, 'one');
    await input.close();
    expect((await prompt.prompt(source: SuppliedAnswer('two')) as Accepted<String>).value, 'two');
  });  test('redirected stdin is not consumed without explicit policy', () async {
    final result = await TextInput('Name').prompt();
    expect(result, isA<Unavailable<String>>());
  });  test('user preference overrides application preference before setup', () async {
    final output = StringBuffer();
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(Stream.value('ok\r'), output, supportsRich: false),
      userPreference: PromptMode.rich, applicationPreference: PromptMode.linear);
    expect(result, isA<Unavailable<String>>());
    expect(output.toString(), isEmpty);
  });  test('automatic mode falls back to command-aware linear entry', () async {
    final result = await TextInput('Name').prompt(
      source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer(), supportsRich: false));
    expect(result, isA<Cancelled<String>>());
  });}









