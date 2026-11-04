import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich Enter adds a newline and Finish accepts it', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(Stream.value('one\rtwo\t\r'), output),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'one\ntwo');
    expect(output.toString(), contains('Finish'));
  });
}
