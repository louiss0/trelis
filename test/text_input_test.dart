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
  });}

