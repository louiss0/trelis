import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'linear edit, insert, list and confirmed removal correct existing lines',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value(
            'first\rsecond\r/list\r/edit\r2\r\x7f!\r/insert\r2\rmiddle\r/remove\r1\ry\r/done\r',
          ),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, 'middle\nsecon!');
      expect(output.toString(), contains('first'));
      expect(output.toString(), contains('second'));
    },
  );
  test('linear entry retains blank and final blank lines until done', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(Stream.value('one\r\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'one\n');
    expect(output.toString(), contains('/done'));
  });
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
