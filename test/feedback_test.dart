import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('Text presents literal safe semantic content', () {
    final output = StringBuffer();
    Text('Careful\x1b[31m!', kind: TextKind.warning).present(output: output);
    expect(output.toString(), 'Warning: Careful\\u001b[31m!\n');
  });
}
