import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'prospective typed path rejects an uninspectable invalid native name',
    () async {
      if (!Platform.isWindows) return;
      final result = await PathInput(
        'Path',
        allowNonexistent: true,
        target: PathTarget.file,
      ).prompt(source: SuppliedAnswer('bad<name'));
      expect(result, isA<Unavailable<String>>());
    },
  );
  test(
    'inaccessible target is not accepted as a prospective typed path',
    () async {
      if (!Platform.isWindows) return;
      final dir = await Directory.systemTemp.createTemp('path-denied-');
      final file = File('${dir.path}\\secret');
      await file.writeAsString('secret');
      final identity = await Process.run('whoami', [
        '/user',
        '/fo',
        'csv',
        '/nh',
      ]);
      final match = RegExp(r'S-1-(?:\d+-)*\d+')
          .firstMatch(identity.stdout as String);
      expect(match, isNotNull);
      final sid = '*${match!.group(0)}';
      addTearDown(() async {
        await Process.run('icacls', [dir.path, '/remove:d', sid]);
        await dir.delete(recursive: true);
      });
      final denied = await Process.run('icacls', [
        dir.path,
        '/deny',
        '$sid:(OI)(CI)(RX)',
      ]);
      expect(denied.exitCode, 0, reason: '${denied.stdout} ${denied.stderr}');
      final result = await PathInput(
        'Path',
        base: dir.path,
        allowNonexistent: true,
        target: PathTarget.file,
      ).prompt(source: SuppliedAnswer('secret'));
      expect(result, isA<Unavailable<String>>());
    },
  );
  test('a file used as a parent is not a prospective path', () async {
    final dir = await Directory.systemTemp.createTemp('path-parent-');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}${Platform.pathSeparator}file').writeAsString('x');
    final result = await PathInput(
      'Path',
      base: dir.path,
      allowNonexistent: true,
      target: PathTarget.file,
    ).prompt(source: SuppliedAnswer('file${Platform.pathSeparator}child'));
    expect(result, isA<Unavailable<String>>());
  });
  test('missing nested target remains allowed with a disclosed type', () async {
    final dir = await Directory.systemTemp.createTemp('path-missing-');
    addTearDown(() => dir.delete(recursive: true));
    final value = 'new${Platform.pathSeparator}child';
    final result = await PathInput(
      'Path',
      base: dir.path,
      allowNonexistent: true,
      target: PathTarget.file,
    ).prompt(source: SuppliedAnswer(value));
    expect(
      (result as Accepted<String>).value,
      '${dir.path}${Platform.pathSeparator}$value',
    );
  });
  test('inspection error keeps draft and base for correction', () async {
    final dir = await Directory.systemTemp.createTemp('path-error-');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}${Platform.pathSeparator}file').writeAsString('x');
    final out = StringBuffer();
    final result =
        await PathInput(
          'Path',
          base: dir.path,
          target: PathTarget.file,
          allowNonexistent: true,
          initialValue: 'file${Platform.pathSeparator}child',
        ).prompt(
          source: ScriptedInput(Stream.value('\r\x03'), out),
          mode: PromptMode.linear,
        );
    expect(result, isA<Interrupted<String>>());
    expect(out.toString(), contains('file${Platform.pathSeparator}child'));
    expect(out.toString(), contains('Base: ${dir.path}'));
    expect(
      out.toString(),
      contains(Platform.isWindows ? 'not a directory' : 'filesystem error'),
    );
  });
}
