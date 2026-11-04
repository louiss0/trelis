import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'supplied unmatched text is accepted without querying suggestions',
    () async {
      var calls = 0;
      final prompt = Autocomplete(
        'Name',
        suggestions: (query) async {
          calls++;
          return ['Ada'];
        },
      );
      final result = await prompt.prompt(source: SuppliedAnswer('Grace'));
      expect((result as Accepted<String>).value, 'Grace');
      expect(calls, 0);
    },
  );
  test(
    'linear candidate acceptance requires explicit final submission',
    () async {
      final output = StringBuffer();
      final result =
          await Autocomplete(
            'Name',
            suggestions: (_) async => ['Ada', 'Grace'],
          ).prompt(
            source: ScriptedInput(Stream.value('A\r2\r/submit\r'), output),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<String>).value, 'Grace');
      expect(output.toString(), contains('1. Ada'));
      expect(output.toString(), contains('2. Grace'));
    },
  );
  test(
    'rich navigation accepts a candidate before a separate submission',
    () async {
      final result = await Autocomplete('Name', suggestions: (_) => ['Ada'])
          .prompt(
            source: ScriptedInput(Stream.value('A\x1b[B\r\r'), StringBuffer()),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'Ada');
    },
  );
}
