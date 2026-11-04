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
  test('Escape dismisses help before cancelling the root', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--test-stream',
    ]);
    p.stdin.write('\x14\x1b');
    await p.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    p.stdin.write('\x03');
    await p.stdin.close();
    final out = await p.stdout.transform(systemEncoding.decoder).join();
    final err = await p.stderr.transform(systemEncoding.decoder).join();
    expect(await p.exitCode, 0);
    expect(out.trim(), 'interrupt');
    expect(err, contains('Help dismissed'));
  });
  test('backspace removes a whole combining grapheme', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--test-stream',
      '--default=ae\u0301',
    ]);
    p.stdin.write('\x7f\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await p.stdout.transform(systemEncoding.decoder).join();
    await p.stderr.drain<void>();
    expect(await p.exitCode, 0);
    expect(out, contains('text:a;'));
  });
  test('removing pasted range restores ordinary command recognition', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--linear',
      '--test-stream',
      '--default=',
    ]);
    p.stdin.write('/cancel\x1b[200~x\x1b[201~\x7f\r');
    await p.stdin.close();
    final out = await p.stdout.transform(systemEncoding.decoder).join();
    await p.stderr.drain<void>();
    expect(await p.exitCode, 0);
    expect(out.trim(), 'cancel');
  });
  test('framed newline paste is rejected without submitting or replaying control input', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--linear',
      '--test-stream',
    ]);
    p.stdin.write('\x1b[200~\n/cancel\x1b[201~\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await p.stdout.transform(systemEncoding.decoder).join();
    final err = await p.stderr.transform(systemEncoding.decoder).join();
    expect(await p.exitCode, 0);
    expect(out, contains('text:alpha;'));
    expect(err, contains('Paste rejected'));
  });
  test('status names each completed validation step without revealing secret', () async {
    final p = await Process.start(Platform.resolvedExecutable, ['run', 'bin/editable_probe.dart', '--test-stream']);
    p.stdin.write('\rsynthetic-secret\rsubmit\r');
    await p.stdin.close();
    final out = await p.stdout.transform(systemEncoding.decoder).join();
    final err = await p.stderr.transform(systemEncoding.decoder).join();
    expect(await p.exitCode, 0);
    expect(err, contains('Validation 1/2: text accepted'));
    expect(err, contains('Validation 2/2: secret accepted'));
    expect(err, isNot(contains('synthetic-secret')));
    expect(out, isNot(contains('synthetic-secret')));
  });}
