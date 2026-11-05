import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('invalid leap day identifies day while retaining the draft', () async {
    final out = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          mode: PromptMode.linear,
          source: ScriptedInput(Stream.value('29/2/2023\r\x03'), out),
        );
    expect(result, isA<Interrupted>());
    expect(out.toString(), contains('Invalid date: day'));
    expect(out.toString(), contains('29/2/2023'));
  });
}
