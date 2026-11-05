import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich slash cannot skip the empty day field', () async {
    final out = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(Stream.value('/\x03'), out),
        );
    expect(result, isA<Interrupted>());
    expect(out.toString(), contains('Slash cannot skip an incomplete field'));
    expect(out.toString(), isNot(contains('Focus: month')));
  });
  test('pasted review command cannot submit', () async {
    final out = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          mode: PromptMode.linear,
          source: ScriptedInput(
            Stream.value('29/2/2024\r\x1b[200~/submit\x1b[201~\r'),
            out,
          ),
        );
    expect(result, isA<InputEnded>());
    expect(out.toString(), contains('Use /submit or /edit'));
  });
}
