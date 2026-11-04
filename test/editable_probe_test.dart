import 'dart:io';
import 'dart:convert';

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
      final outFuture = p.stdout.transform(systemEncoding.decoder).join();
      final errFuture = p.stderr.transform(systemEncoding.decoder).join();
      p.stdin.write('\x01\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~\r');
      await p.stdin.flush();
      p.stdin.write('fixed\rtest-secret\rsubmit\r');
      await p.stdin.close();
      final out = await outFuture;
      final err = await errFuture;
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
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('\x14\x1b');
    await p.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    p.stdin.write('\x03');
    await p.stdin.close();
    final out = await outFuture;
    final err = await errFuture;
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
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('\x7f\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await outFuture;
    await errFuture;
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
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('/cancel\x1b[200~x\x1b[201~\x7f\r');
    await p.stdin.close();
    final out = await outFuture;
    await errFuture;
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
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('\x1b[200~\n/cancel\x1b[201~\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await outFuture;
    final err = await errFuture;
    expect(await p.exitCode, 0);
    expect(out, contains('text:alpha;'));
    expect(err, contains('Paste rejected'));
  });
  test(
    'status names each completed validation step without revealing secret',
    () async {
      final p = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/editable_probe.dart',
        '--test-stream',
      ]);
      final outFuture = p.stdout.transform(systemEncoding.decoder).join();
      final errFuture = p.stderr.transform(systemEncoding.decoder).join();
      p.stdin.write('\rsynthetic-secret\rsubmit\r');
      await p.stdin.close();
      final out = await outFuture;
      final err = await errFuture;
      expect(await p.exitCode, 0);
      expect(err, contains('Validation 1/2: text accepted'));
      expect(err, contains('Validation 2/2: secret accepted'));
      expect(err, isNot(contains('synthetic-secret')));
      expect(out, isNot(contains('synthetic-secret')));
    },
  );
  test(
    'pasting before a quoted default does not turn representation into data',
    () async {
      final p = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/editable_probe.dart',
        '--linear',
        '--test-stream',
        '--default=/cancel',
      ]);
      final outFuture = p.stdout.transform(systemEncoding.decoder).join();
      final errFuture = p.stderr.transform(systemEncoding.decoder).join();
      p.stdin.write('\x01\x1b[200~x\x1b[201~\rsecret\rsubmit\r');
      await p.stdin.close();
      final out = await outFuture;
      await errFuture;
      expect(await p.exitCode, 0);
      expect(out, contains('text:x/cancel;'));
    },
  );
  test('linear editing produces sequential reviewable states', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--linear',
      '--test-stream',
    ]);
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('x\rsecret\rsubmit\r');
    await p.stdin.close();
    await outFuture;
    final err = await errFuture;
    expect(await p.exitCode, 0);
    expect(err, contains('Current text: alpha\n'));
    expect(err, contains('Current text: alphax\n'));
    expect(err, isNot(contains('\x1b[2K')));
  });
  test('rich cursor uses terminal save and restore instead of grapheme count as cell width', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--test-stream',
      '--default=A\u754c',
    ]);
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(utf8.decoder).join();
    p.stdin.write('\x1b[D\rsecret\rsubmit\r');
    await p.stdin.close();
    await outFuture;
    final err = await errFuture;
    expect(await p.exitCode, 0);
    expect(err, contains('A\x1b[s\u754c\x1b[u'));
  });
  test('oversized framed paste is rejected as a unit and later input remains usable', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--test-stream',
    ]);
    final outFuture = p.stdout.transform(systemEncoding.decoder).join();
    final errFuture = p.stderr.transform(systemEncoding.decoder).join();
    p.stdin.write('\x1b[200~${'x' * 5000}\x1b[201~\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await outFuture;
    final err = await errFuture;
    expect(await p.exitCode, 0);
    expect(out, contains('text:alpha;'));
    expect(err, contains('Paste rejected: exceeds 4096'));
  });
  test('pasted combining mark joins adjacent grapheme and deletion removes its provenance', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--linear',
      '--test-stream',
      '--default=/cancelx',
    ]);
    final outFuture = p.stdout.transform(utf8.decoder).join();
    final errFuture = p.stderr.transform(utf8.decoder).join();
    p.stdin.write('\x1b[200~\u0301\x1b[201~\x7f\r');
    await p.stdin.close();
    final out = await outFuture;
    await errFuture;
    expect(await p.exitCode, 0);
    expect(out.trim(), 'cancel');
  });
  test(
    'pasted combining mark next to representation escape remains literal data',
    () async {
      final p = await Process.start(Platform.resolvedExecutable, [
        'run',
        'bin/editable_probe.dart',
        '--linear',
        '--test-stream',
        '--default=/cancel',
      ]);
      final outFuture = p.stdout.transform(utf8.decoder).join();
      final errFuture = p.stderr.transform(utf8.decoder).join();
      p.stdin.write('\x01\x1b[C\x1b[200~\u0301\x1b[201~\rsecret\rsubmit\r');
      await p.stdin.close();
      final out = await outFuture;
      await errFuture;
      expect(await p.exitCode, 0);
      expect(out, contains('text:\u0301/cancel;'));
    },
  );
  test('pasted command stays data after an adjacent edit is undone', () async {
    final p = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/editable_probe.dart',
      '--linear',
      '--test-stream',
      '--default=',
    ]);
    final outFuture = p.stdout.transform(utf8.decoder).join();
    final errFuture = p.stderr.transform(utf8.decoder).join();
    p.stdin.write('\x1b[200~/cancel\x1b[201~x\x7f\rsecret\rsubmit\r');
    await p.stdin.close();
    final out = await outFuture;
    await errFuture;
    expect(await p.exitCode, 0);
    expect(out, contains('text:/cancel;'));
  });
}
