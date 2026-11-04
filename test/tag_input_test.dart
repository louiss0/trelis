import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('snake style uses the configured separator', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags', style: TagStyle.snakeCase).prompt(
      source: ScriptedInput(Stream.value('HTTPServer\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['http_server']);
    expect(output.toString(), contains('snake'));
  });
  test('acronym and Unicode word boundaries produce canonical tags', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('HTTPServer\rDéjà Vu\r/done\r'),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, [
      'http-server',
      'déjà-vu',
    ]);
  });

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
