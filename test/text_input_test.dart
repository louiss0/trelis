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
}
