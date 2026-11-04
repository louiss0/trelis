import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'rich probe rejects redirected streams without terminal setup',
    () async {
      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/terminal_probe.dart',
      ]);
      await process.stdin.close();
      final out = await process.stdout.transform(systemEncoding.decoder).join();
      final err = await process.stderr.transform(systemEncoding.decoder).join();
      expect(await process.exitCode, 2);
      expect(out, isEmpty);
      expect(err, contains('rich interaction unavailable'));
      expect(err, isNot(contains('\u001b')));
    },
  );
}
