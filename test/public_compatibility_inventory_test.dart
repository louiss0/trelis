import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// Source-level checks of the public inventory after the breaking cutover.
///
/// The external-package fixture in `fixtures/public_api_fixture` performs the
/// compile-time half of this check: it constructs every family through theme
/// instances and verifies that static factories, direct constructors,
/// invocation configuration and supplied-answer types are rejected.
void main() {
  group('public authoring surface', () {
    test('the barrel exports only the documented public libraries', () {
      final exports = File('lib/trelis.dart')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.startsWith('export '))
          .toList();

      expect(exports.where((line) => line.contains('src/themes/')), [
        "export 'src/themes/plain_theme.dart';",
        "export 'src/themes/rail_theme.dart';",
        "export 'src/themes/branch_theme.dart';",
        "export 'src/themes/box_theme.dart';",
        "export 'src/themes/round_theme.dart';",
        "export 'src/themes/double_theme.dart';",
        "export 'src/themes/minimal_theme.dart';",
        "export 'src/themes/ascii_theme.dart';",
        "export 'src/themes/chevron_theme.dart';",
        "export 'src/themes/bracket_theme.dart';",
        "export 'src/themes/form_theme.dart';",
        "export 'src/themes/ledger_theme.dart';",
        "export 'src/themes/colon_theme.dart';",
        "export 'src/themes/line_theme.dart';",
        "export 'src/themes/block_theme.dart';",
      ]);
      expect(exports, contains("export 'src/public_theme_api.dart';"));
      expect(exports, isNot(contains("export 'src/text_input.dart';")));
      expect(exports, isNot(contains("export 'src/feedback.dart';")));
      expect(exports.any((line) => line.contains(' show ')), isTrue);
    });

    test('result, choice and value types remain public', () {
      final PromptResult<String> accepted = Accepted('answer');
      final PromptResult<String> ended = InputEnded<String>();
      final PromptResult<String> unavailable = Unavailable<String>('reason');
      expect(accepted, isA<Accepted<String>>());
      expect(ended, isA<InputEnded<String>>());
      expect(unavailable, isA<Unavailable<String>>());

      final choice = Choice<int>(1, 'One', disabledReason: 'reason');
      final node = TreeNode<int>(1, 'Node', children: [TreeNode(2, 'Child')]);
      // Component answers remain nameable from an external package even
      // though they are produced only through theme prompts.
      PromptResult<KeyGesture>? keyResult;
      PromptResult<CivilDate>? dateResult;
      PromptResult<DurationValue>? durationResult;
      expect(choice.value, 1);
      expect(node.children, hasLength(1));
      expect(keyResult, isNull);
      expect(dateResult, isNull);
      expect(durationResult, isNull);
    });

    test(
      'public source has no supplied-answer or invocation configuration',
      () {
        final sources = <File>[
          File('lib/trelis.dart'),
          File('lib/src/public_theme_api.dart'),
          ...Directory('lib/src/themes')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('_theme.dart')),
        ];
        for (final source in sources) {
          final text = source
              .readAsLinesSync()
              .where((line) => !line.trimLeft().startsWith('//'))
              // Internal delegation binds the theme-owned session; only public
              // parameter declarations are under test here.
              .where((line) => !RegExp(r'^\s*(session|io): _').hasMatch(line))
              .join('\n');
          for (final banned in [
            'SuppliedAnswer',
            'SuppliedTags',
            'PromptSource',
            'source:',
            'session:',
            'output:',
            'terminal:',
            'outputProfile:',
            'userPreference:',
            'applicationPreference:',
          ]) {
            expect(
              text,
              isNot(contains(banned)),
              reason: '${source.path} must not expose $banned',
            );
          }
        }
      },
    );

    test('the external fixture compiles against the public barrel', () {
      final fixture = File('fixtures/public_api_fixture/bin/positive.dart');
      final source = fixture.readAsStringSync();
      expect(source, contains("import 'package:trelis/trelis.dart';"));
      expect(source, isNot(contains('package:trelis/src/')));
      expect(
        RegExp(r'ThemePrompt<[^>]+>').allMatches(source),
        hasLength(greaterThanOrEqualTo(34)),
      );
    });
  });
}
