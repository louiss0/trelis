import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test('rich Tab traverses segments and review action', () async {
    final out = StringBuffer();
    final result =
        await DateInput(
          'Date',
          order: DateFieldOrder.dayMonthYear,
          initialValue: '29/02/2024',
        ).prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(
            Stream.value('\t\t\t\r\t\r'),
            out,
            outputProfile: _dateRichProfile,
          ),
        );
    expect(result, isA<Accepted<CivilDate>>());
    expect(out.toString(), contains('Focus: Review'));
  });
}

final _dateRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);
