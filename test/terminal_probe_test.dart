import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'explicit stream stdin reports actual end of stream, not partial input',
    () async {
      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/terminal_probe.dart',
        '--stream-stdin',
      ]);
      process.stdin.write('partial');
      await process.stdin.close();
      final out = await process.stdout.transform(systemEncoding.decoder).join();
      final err = await process.stderr.transform(systemEncoding.decoder).join();
      expect(await process.exitCode, 0);
      expect(out.trim(), 'eof');
      expect(err, isNot(contains('\u001b')));
    },
  );

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
