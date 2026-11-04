import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'linear initial value is editable and erasing it fails validation',
    () async {
      final p = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/editable_probe.dart',
        '--linear',
        '--test-stream',
      ]);
      p.stdin.write('\x01\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~\r');
      await p.stdin.flush();
      p.stdin.write('fixed\rtest-secret\rsubmit\r');
      await p.stdin.close();
      final out = await p.stdout.transform(systemEncoding.decoder).join();
      final err = await p.stderr.transform(systemEncoding.decoder).join();
      expect(await p.exitCode, 0);
      expect(err, contains('Required'));
      expect(out, contains('text:fixed'));
    },
  );
}


