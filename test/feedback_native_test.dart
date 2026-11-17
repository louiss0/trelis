import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'redirected feedback stays on stdout and contains no terminal controls',
    () async {
      final process = await Process.run(Platform.resolvedExecutable, [
        'run',
        'test/feedback_native_app.dart',
      ]);
      expect(process.exitCode, 0, reason: '${process.stderr}');
      expect(process.stderr, isEmpty);
      final out = process.stdout as String;
      expect(out, contains('application result\n'));
      expect(out, contains(r'Warning: literal\u001b[31m'));
      expect(out, contains('running, 20%'));
      expect(out, contains('failed: network unavailable'));
      expect(out, contains('Connection: skipped'));
      expect(
        out,
        contains('Summary:\nbuild: completed\ntest: failed: test failure'),
      );
      expect(out, isNot(contains('\x1b')));
      expect(out, isNot(contains('\r')));
    },
  );
}
