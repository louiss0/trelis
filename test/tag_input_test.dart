import 'dart:async';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

/// Synthetic rich output declares positive geometry; the legacy rich hint is
/// not geometry evidence.
final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

void main() {
  test(
    'snake policy preserves Unicode and uses word-aware separators',
    () async {
      final result = await TagInput('Tags', style: TagStyle.snakeCase).prompt(
        source: SuppliedTags([
          'My NewTag',
          'HTTPServer',
          'Déjà Vu',
          '__Cafe\u0301--Noir__',
        ]),
      );
      expect((result as Accepted<List<String>>).value, [
        'my_new_tag',
        'http_server',
        'déjà_vu',
        'cafe\u0301_noir',
      ]);
    },
  );
  test('supplied canonical duplicates are rejected in both styles', () async {
    for (final style in TagStyle.values) {
      final result = await TagInput(
        'Tags',
        style: style,
      ).prompt(source: SuppliedTags(['HelloWorld', 'hello world']));
      expect(result, isA<Unavailable<List<String>>>());
    }
  });
  test(
    'linear rejected draft can be explicitly discarded before finishing',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(Stream.value('bad!\r\x18/done\r'), output),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, isEmpty);
      expect(output.toString(), contains('Draft discarded'));
    },
  );
  test(
    'supplied tag collection returns validated canonical ordered values',
    () async {
      final result = await TagInput('Tags')
          .prompt(source: SuppliedTags(['My Tag', 'HTTPServer']));
      expect((result as Accepted<List<String>>).value, [
        'my-tag',
        'http-server',
      ]);
    },
  );
  test('rich draft must be explicitly discarded before finish', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('unfinished\t\r\x18\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<String>>).value, isEmpty);
    expect(output.toString(), contains('discard'));
    expect(output.toString(), contains('Draft discarded'));
  });
  test('orphan combining mark is rejected while editable', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(Stream.value('\u0301\r\x7fCafe\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['cafe']);
    expect(output.toString(), contains('Combining'));
  });
  test(
    'caller validates canonical tags and rejected drafts remain editable',
    () async {
      final output = StringBuffer();
      final result =
          await TagInput(
            'Tags',
            validate: (value) => value == 'new-tag' ? 'Not allowed' : null,
          ).prompt(
            source: ScriptedInput(
              Stream.value('NewTag\r\x7f\x7f\x7fOne\r/done\r'),
              output,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<List<String>>).value, ['new-one']);
      expect(output.toString(), contains('Not allowed'));
    },
  );
  test('rich navigation edits an earlier tag without reordering', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value(
          'one\rtwo\r\x7f\x1b[D\r\x01\x1b[3~\x1b[3~\x1b[3~first\r\t\r',
        ),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<String>>).value, ['first', 'two']);
    expect(output.toString(), contains('Editing: one'));
  });
  test('rich slash command text remains a literal draft', () async {
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('/done\r\x03'),
        StringBuffer(),
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Interrupted<List<String>>>());
  });
  test('automatic mode previews drafts on rich-capable source', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('NewTag\r\t\r'),
        output,
        outputProfile: _richProfile,
      ),
    );
    expect((result as Accepted<List<String>>).value, ['new-tag']);
    expect(output.toString(), contains('Preview: new-tag'));
  });
  test('native prompt without a terminal reports unavailable', () async {
    final result = await TagInput('Tags').prompt();
    expect(result, isA<Unavailable<List<String>>>());
  });
  test(
    'supplied invalid single tag yields unavailable rather than throwing',
    () async {
      final result = await TagInput('Tags')
          .prompt(source: SuppliedAnswer('bad!'));
      expect(result, isA<Unavailable<List<String>>>());
    },
  );
  test('rich focused tag can be edited in place', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('one\rtwo\r\x7f\r\x01\x1b[3~\x1b[3~\x1b[3~NewTag\r\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<String>>).value, ['one', 'new-tag']);
    expect(output.toString(), contains('Editing: two'));
  });
  test('rich backspace focuses last tag and only Delete removes it', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('one\rtwo\r\x7f\x7f\x1b[3~\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<String>>).value, ['one']);
    expect(output.toString(), contains('Focused: two'));
    expect(output.toString(), contains('Removed: two'));
  });
  test(
    'canonical length validation retains the draft for correction',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags', maxLength: 5).prompt(
        source: ScriptedInput(
          Stream.value('HelloWorld\r\x7f\x7f\x7f\x7f\x7f\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['hello']);
      expect(output.toString(), contains('Maximum 5'));
    },
  );
  test('overlapping sessions on the same prompt are rejected', () async {
    final input = StreamController<String>();
    final prompt = TagInput('Tags');
    final first = prompt.prompt(
      source: ScriptedInput(input.stream, StringBuffer()),
      mode: PromptMode.linear,
    );
    await expectLater(
      prompt.prompt(
        source: ScriptedInput(Stream.value('/done\r'), StringBuffer()),
        mode: PromptMode.linear,
      ),
      throwsStateError,
    );
    input.add('/done\r');
    expect(await first, isA<Accepted<List<String>>>());
    await input.close();
  });
  test('rich mode previews canonical draft without rewriting input', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('NewTag\r\t\r'),
        output,
        outputProfile: _richProfile,
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<List<String>>).value, ['new-tag']);
    expect(output.toString(), contains('Preview: new-tag'));
  });
  test(
    'pasted finish command is literal and cannot finish collection',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('\x1b[200~/done\x1b[201~\r\x03'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect(result, isA<Interrupted<List<String>>>());
      expect(output.toString(), contains('punctuation'));
    },
  );
  test('combining marks remain attached across camel boundaries', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(Stream.value('Cafe\u0301World\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['cafe\u0301-world']);
  });
  test('linear editing replaces selected tag in place', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value(
          'one\rtwo\r/edit\r1\r\x01\x1b[3~\x1b[3~\x1b[3~New Value\r/done\r',
        ),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['new-value', 'two']);
  });
  test('linear removal selects a tag explicitly and preserves order', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('one\rtwo\rthree\r/list\r/remove\r2\r/done\r'),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['one', 'three']);
    expect(output.toString(), contains('2. two'));
  });
  test('explicit rich mode is unavailable on incapable source', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('value\r/done\r'),
        output,
        supportsRich: false,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Unavailable<List<String>>>());
  });
  test(
    'separator edges are removed and empty drafts do not add tags',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('\r--Hello World__\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['hello-world']);
      expect(output.toString(), contains('Finish'));
    },
  );
  test(
    'unsupported punctuation is rejected and draft remains editable',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('hello!\r\x7f world\r/done\r'),
          output,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['hello-world']);
      expect(output.toString(), contains('punctuation'));
    },
  );
  test('canonical duplicate remains editable and is not added', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value(
          'HelloWorld\rhello world\r\x7f\x7f\x7f\x7f\x7fthere\r/done\r',
        ),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, [
      'hello-world',
      'hello-there',
    ]);
    expect(output.toString(), contains('Duplicate'));
  });

  test('snake style uses the configured separator', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags', style: TagStyle.snakeCase).prompt(
      source: ScriptedInput(Stream.value('HTTPServer\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['http_server']);
    expect(output.toString(), contains('snake'));
  });
  test('acronym and Unicode word boundaries produce canonical tags', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(
        Stream.value('HTTPServer\rDéjà Vu\r/done\r'),
        output,
      ),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, [
      'http-server',
      'déjà-vu',
    ]);
  });

  test('linear entry adds canonical tag and explicitly finishes', () async {
    final output = StringBuffer();
    final result = await TagInput('Tags').prompt(
      source: ScriptedInput(Stream.value('My NewTag\r/done\r'), output),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, ['my-new-tag']);
    expect(output.toString(), contains('my-new-tag'));
  });
}
