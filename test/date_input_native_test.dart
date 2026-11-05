import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('native rich DateInput refuses redirected streams', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/date_input_native_app.dart',
    ]);
    process.stdin.write('29/2/2024\r/submit\r');
    await process.stdin.close();
    final out = await process.stdout.transform(systemEncoding.decoder).join();
    final err = await process.stderr.transform(systemEncoding.decoder).join();
    expect(await process.exitCode, 0, reason: err);
    expect(out.trim(), 'unavailable');
    expect(err, isNot(contains('\x1b')));
  });
}
