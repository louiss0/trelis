import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// Source-level checks of the public inventory after the breaking cutover.
///
/// These checks compare meaningful sets: export membership, the theme classes
/// the public libraries declare, and the surface the external fixture
/// exercises. Export ordering and fixture formatting are not contractual, so
/// no assertion depends on source ordering or literal fixture layout. Compile
/// acceptance and rejection of the public surface belong to the external
/// checker in `tool/check_public_api.dart`, which analyzes
/// `fixtures/public_api_fixture` as an external package.
void main() {
  group('public authoring surface', () {
    test('the barrel exports exactly the documented theme libraries', () {
      final exports = File('lib/trelis.dart')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.startsWith('export '))
          .toList();

      // Membership is the contract; the order of export directives is not.
      expect(
        exports.where((line) => line.contains('src/themes/')),
        unorderedEquals([
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
        ]),
      );
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

    test(
      'the external fixture exercises the full public inventory as sets',
      () {
        final fixture = File('fixtures/public_api_fixture/bin/positive.dart')
            .readAsStringSync();

        // The fixture must remain an external-package consumer: compile
        // evidence is only meaningful when nothing internal is reachable.
        expect(fixture, contains("import 'package:trelis/trelis.dart';"));
        expect(fixture, isNot(contains('package:trelis/src/')));

        // Every structural theme class the public libraries declare must be
        // constructed in the fixture, and the fixture must not invent theme
        // classes the libraries do not declare. Both directions are set
        // comparisons, so reformatting or reordering either side cannot fail.
        final declaredThemes = <String>{};
        for (final file
            in Directory('lib/src/themes')
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('_theme.dart'))) {
          final source = file.readAsStringSync();
          declaredThemes.addAll(
            RegExp(r'final class (\w+Theme) ')
                .allMatches(source)
                .map((match) => match.group(1)!),
          );
        }
        final fixtureThemes = RegExp(r'(\w+Theme)\(io: io\)')
            .allMatches(fixture)
            .map((match) => match.group(1)!)
            .toSet();
        expect(
          fixtureThemes,
          unorderedEquals(declaredThemes),
          reason:
              'the fixture must construct every exported theme exactly '
              'the way an external package can',
        );

        // Every prompt and feedback factory the theme API declares must be
        // exercised through the `theme.` seam in the fixture. Declaration
        // names come from the public theme source, invocation names from the
        // fixture; comparing the sets catches drift in either direction.
        final apiSource = File('lib/src/public_theme_api.dart')
            .readAsStringSync();
        final declaredMethods =
            RegExp(
                  r'^\s{2}Theme(?:Prompt|Feedback|LiveFeedback)(?:<.+?>)?\s+(\w+)(?:<\w+>)?\(',
                  multiLine: true,
                )
                .allMatches(apiSource)
                .map((match) => match.group(1)!)
                .where((name) => !name.startsWith('_'))
                .toSet();
        final fixtureMethods = RegExp(r'theme\s*\.\s*(\w+)(?:<[^>\n]*>)?\s*\(')
            .allMatches(fixture)
            .map((match) => match.group(1)!)
            .toSet();
        expect(
          fixtureMethods,
          unorderedEquals(declaredMethods),
          reason:
              'every declared theme factory must be exercised through '
              'the external fixture',
        );
        expect(
          declaredMethods,
          hasLength(greaterThanOrEqualTo(34)),
          reason: 'the public inventory itself must not silently shrink',
        );
      },
    );
  });
}
