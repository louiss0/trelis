import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

/// The transcript with the writer's line breaks removed.
///
/// The shared writer wraps at display cells, so a continuation line starts with
/// the preserved separator space and a long token is split across the boundary.
/// Content assertions therefore cannot rely on a phrase landing inside one
/// line: removing `\r`/`\n` rebuilds the text the user actually reads without
/// changing any content.
String _displaySafeText(String transcript) =>
    transcript.replaceAll('\n', '').replaceAll('\r', '');

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
  // Both base lengths are exercised because the writer wraps at display cells:
  // an assertion on literal content must not depend on where a line breaks.
  for (final longBase in [false, true]) {
    test('rich entry preserves invalid draft and context '
        '(${longBase ? 'long' : 'short'} base)', () async {
      final root = await Directory.systemTemp.createTemp('path-wrapping-');
      addTearDown(() => root.delete(recursive: true));
      final base = await Directory(
        path.join(root.path, longBase ? 'long-${'x' * 60}' : 'b'),
      ).create();
      final out = StringBuffer();
      final result = await PathInput('Path', base: base.path).prompt(
        source: ScriptedInput(
          Stream.value('missing\r\x7f\x7f\x7f\x7f\x7f\x7f\x7f.\r\r'),
          out,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<Accepted<String>>());
      final transcript = _displaySafeText(out.toString());
      // The absent draft is refused with its protected reason and context. The
      // reason may be the exact absence wording or the fail-closed inspection
      // message, because the native last error is read by a second FFI call and
      // can be lost (see
      // doc/evidence/trelis-backend/27-filesystem-migration.md): the contract
      // refuses rather than inferring absence, so neither wording may be
      // demanded as the only truthful one.
      expect(
        transcript,
        contains('Candidate: ${base.path}${path.separator}missing'),
      );
      expect(
        transcript,
        anyOf(contains('Target must exist'), contains('Cannot inspect target')),
      );
      expect(transcript, contains('Base: ${base.path}'));
    });
  }
}
