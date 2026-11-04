import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('a supplied answer is accepted without interpreting commands', () async {
    final prompt = TextInput('Name');
    final result = await prompt.prompt(source: SuppliedAnswer('/cancel'));
    expect(result, isA<Accepted<String>>());
    expect((result as Accepted<String>).value, '/cancel');
  });
}
