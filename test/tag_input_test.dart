import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear removal selects a tag explicitly and preserves order', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('one\rtwo\rthree\r/list\r/remove\r2\r/done\r'),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['one', 'three']);
    expect(output.toString(), contains('2. two'));
  });
  test('explicit rich mode is unavailable on incapable source', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('value\r/done\r'),
        output,
        supportsRich: false,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Unavailable<List<String>>>());
  });
  test(
    'separator edges are removed and empty drafts do not add tags',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('\r--Hello World__\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['hello-world']);
      expect(output.toString(), contains('Finish'));
    },
  );
  test(
    'unsupported punctuation is rejected and draft remains editable',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('hello!\r\x7f world\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['hello-world']);
      expect(output.toString(), contains('punctuation'));
    },
  );
  test('canonical duplicate remains editable and is not added', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value(
          'HelloWorld\rhello world\r\x7f\x7f\x7f\x7f\x7fthere\r/done\r',
        ),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, [
      'hello-world',
      'hello-there',
    ]);
    expect(output.toString(), contains('Duplicate'));
  });

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
