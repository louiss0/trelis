import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('maximal Unix step completes without arithmetic wraparound', () async {
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/cron_large_step_probe.dart',
    ]);
    try {
      // Covers the cold JIT compile of the probe script on a loaded runner; the
      // bounded work itself finishes immediately because the budget is one
      // candidate.
      final code = await process.exitCode.timeout(const Duration(seconds: 90));
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
