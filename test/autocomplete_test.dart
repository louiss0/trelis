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
}
