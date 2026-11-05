import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('maximal Unix step completes without arithmetic wraparound', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/cron_large_step_probe.dart',
    ]);
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 10));
      final output = await process.stdout
          .transform(systemEncoding.decoder)
          .join();
      expect(code, 0);
      expect(output.trim(), '2024-01-01T00:00:00.000Z');
    } finally {
      process.kill();
    }
  });
}
