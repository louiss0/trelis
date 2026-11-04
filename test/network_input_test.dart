import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('port accepts a numeric service port', () async {
    final result = await PortInput('Port')
        .prompt(source: SuppliedAnswer('443'));
    expect((result as Accepted<int>).value, 443);
  });
}
