import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'rich adjustment preserves invalid dependent day for correction',
    () async {
      final output = StringBuffer();
      final result =
          await DateInput(
            'Date',
            order: DateFieldOrder.dayMonthYear,
            initialValue: '31/01/2024',
          ).prompt(
            mode: PromptMode.rich,
            source: ScriptedInput(
              Stream.value('\t+\t\r\x03'),
              output,
              outputProfile: _dateRichProfile,
            ),
          );
      expect(result, isA<Interrupted<CivilDate>>());
      expect(output.toString(), contains('Invalid date'));
    },
  );
}

final _dateRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);
