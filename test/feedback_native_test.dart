import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'redirected feedback stays on stderr and contains no terminal controls',
    () async {
      final process = await Process.run(Platform.resolvedExecutable, [
        'run',
        'test/feedback_native_app.dart',
      ]);
      expect(process.exitCode, 0, reason: '${process.stderr}');
      expect(process.stdout, 'application result\n');
      final err = process.stderr as String;
      expect(err, contains(r'Warning: literal\u001b[31m'));
      expect(err, contains('running, 20%'));
      expect(err, contains('failed: network unavailable'));
      expect(err, contains('Connection: skipped'));
      expect(err, isNot(contains('\x1b')));
      expect(err, isNot(contains('\r')));
    },
  );
}
