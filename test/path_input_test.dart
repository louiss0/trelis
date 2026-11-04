import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'supplied literal prospective path resolves against the explicit base',
    () async {
      final result = await PathInput(
        'Path',
        base: r'C:\base',
        allowNonexistent: true,
      ).prompt(source: SuppliedAnswer(r'folder\..\$HOME'));
      expect((result as Accepted<String>).value, r'C:\base\folder\..\$HOME');
    },
  );
}
