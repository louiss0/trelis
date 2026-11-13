import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

void main() {
  test('default requires existence and target type is enforced', () async {
    final dir = await Directory.systemTemp.createTemp('path-input-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(path.join(dir.path, 'file'));
    await file.writeAsString('x');
    expect(
      await PathInput(
        'Path',
        base: dir.path,
      ).prompt(source: SuppliedAnswer('missing')),
      isA<Unavailable>(),
    );
    expect(
      await PathInput(
        'Path',
        base: dir.path,
        target: PathTarget.directory,
      ).prompt(source: SuppliedAnswer('file')),
      isA<Unavailable>(),
    );
    expect(
      (await PathInput(
        'Path',
        base: dir.path,
        target: PathTarget.file,
      ).prompt(source: SuppliedAnswer('file')) as Accepted<String>).value,
      file.path,
    );
  });
  test(
    'linear entry quotes command collisions and reviews candidate',
    () async {
      final out = StringBuffer();
      final base = Directory.current.path;
      final result = await PathInput('Path', base: base, allowNonexistent: true)
          .prompt(
            source: ScriptedInput(
              Stream.value(
                r'\/cancel'
                '\r\r',
              ),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect(
        (result as Accepted<String>).value,
        Platform.isWindows ? '${path.rootPrefix(base)}cancel' : '/cancel',
      );
      expect(out.toString(), contains('Resolved candidate:'));
    },
  );
  test('rich entry preserves invalid draft and context', () async {
    final out = StringBuffer();
    final result = await PathInput('Path', base: Directory.current.path).prompt(
      source: ScriptedInput(
        Stream.value('missing\r\x7f\x7f\x7f\x7f\x7f\x7f\x7f.\r\r'),
        out,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Accepted<String>>());
    expect(out.toString(), contains('Target must exist'));
    expect(out.toString(), contains('Base: ${Directory.current.path}'));
  });
}
