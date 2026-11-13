import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('rich slash moves through segments and date is reviewed', () async {
    final out = StringBuffer();
    final result = await DateInput('Date', order: DateFieldOrder.dayMonthYear)
        .prompt(
          source: ScriptedInput(
            Stream.value('29/02/2024\r/submit\r'),
            out,
            outputProfile: _dateRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect(result, isA<Accepted<CivilDate>>());
    expect(out.toString(), contains('Focus: month'));
    expect(out.toString(), contains('Focus: year'));
  });
}

final _dateRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);
