import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test('rich reverse navigation works with delivered Ctrl+B', () async {
    final out = StringBuffer();
    final result =
        await DateInput(
          'Date',
          order: DateFieldOrder.dayMonthYear,
          initialValue: '29/02/2024',
        ).prompt(
          mode: PromptMode.rich,
          source: ScriptedInput(
            Stream.value('\t\x02\x03'),
            out,
            outputProfile: _dateRichProfile,
          ),
        );
    expect(result, isA<Interrupted>());
    expect('Focus: day'.allMatches(out.toString()).length, 2);
    expect(out.toString(), contains('Ctrl+B'));
  });
}

final _dateRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);
