import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
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
