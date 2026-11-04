import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('an unavailable default is explained instead of substituted', () async {
    final out = StringBuffer();
    final result =
        await TimezoneSelect(
          'Zone',
          defaultValue: 'US/Eastern',
          unavailable: {'America/New_York': 'not supported'},
        ).prompt(
          source: ScriptedInput(Stream.value('\r\r\x1b'), out),
          mode: PromptMode.rich,
        );
    expect(result, isA<InputEnded<String>>());
    expect(out.toString(), contains('not supported'));
  });
  test('an alias default retains its canonical identity', () async {
    final result = await TimezoneSelect('Zone', defaultValue: 'US/Eastern')
        .prompt(
          source: ScriptedInput(Stream.value('\r\r'), StringBuffer()),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'America/New_York');
  });
  test(
    'rich Enter opens results before accepting the default identity',
    () async {
      final out = StringBuffer();
      final result = await TimezoneSelect('Zone', defaultValue: 'Asia/Tokyo')
          .prompt(
            source: ScriptedInput(Stream.value('\r\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Asia/Tokyo');
      expect(out.toString(), contains('Results focused.'));
    },
  );
  test('linear search returns canonical IANA identity for an alias', () async {
    final out = StringBuffer();
    final result = await TimezoneSelect('Zone').prompt(
      source: ScriptedInput(Stream.value('US/Eastern\r105\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'America/New_York');
    expect(out.toString(), contains('2025c'));
  });
}
