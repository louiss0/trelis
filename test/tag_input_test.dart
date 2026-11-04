import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear entry adds canonical tag and explicitly finishes', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(Stream.value('My NewTag\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['my-new-tag']);
    expect(output.toString(), contains('my-new-tag'));
  });
}
