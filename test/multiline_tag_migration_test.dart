import 'dart:async';
import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

OutputProfile _rich({int columns = 80, int rows = 24}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: columns, rows: rows),
);

void main() {
  test('a declared rich profile enables Multiline rich editing', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes').prompt(
      source: ScriptedInput(
        Stream.value('one\rtwo\t\r'),
        output,
        supportsRich: false,
        outputProfile: _rich(),
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'one\ntwo');
  });

  test(
    'Multiline rich mode stays unavailable without declared capability',
    () async {
      final output = StringBuffer();
      final result = await Multiline('Notes').prompt(
        source: ScriptedInput(
          Stream.value('one\r'),
          output,
          supportsRich: false,
        ),
        mode: PromptMode.rich,
      );
      expect(result, isA<Unavailable<String>>());
      expect(output.toString(), isEmpty);
    },
  );

  test('a terminal lease and competing invocation are explicit', () async {
    final output = StringBuffer();
    final terminal = _MigrationTerminal(
      Stream.value('one\rtwo\t\r'),
      output,
      _rich(),
    );
    final result = await Multiline('Notes')
        .prompt(terminal: terminal, mode: PromptMode.rich);
    expect((result as Accepted<String>).value, 'one\ntwo');
    expect(terminal.events, ['acquire', 'restore']);

    await expectLater(
      Multiline('Notes').prompt(
        source: ScriptedInput(Stream.value(''), StringBuffer()),
        terminal: terminal,
      ),
      throwsArgumentError,
    );
    await expectLater(
      Multiline('Notes').prompt(output: stderr, terminal: terminal),
      throwsArgumentError,
    );
  });

  test(
    'a Multiline prompt keeps its draft while session feedback updates',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Upload');
          spinner.start(session: session);
          final pending = Multiline('Notes').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('one\r');
          await Future<void>.delayed(Duration.zero);
          final beforeUpdate = output.toString();
          spinner.update('uploading');
          await Future<void>.delayed(Duration.zero);
          // The session repaints the editable line after the status write, so
          // the caret and draft stay on screen without another keypress.
          final update = output.toString().substring(beforeUpdate.length);
          expect(update, contains('[status] Upload: uploading'));
          expect(update, contains('Line 2:'));
          input.add('two\t\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(input.stream, output, outputProfile: _rich()),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<String>).value, 'one\ntwo');
      expect(output.toString(), contains('[status] Upload: uploading'));
    },
  );

  test('rich Multiline help describes its own editing stages', () async {
    final output = StringBuffer();
    final result = await Multiline('Notes', maxLength: 5).prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\t\r'),
        output,
        outputProfile: _rich(columns: 40),
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, isEmpty);
    final text = output.toString();
    expect(text, contains('Help:'));
    // Help is wrapped to the declared column count, so compare content
    // without depending on where the wrap falls.
    final help = text.substring(
      text.indexOf('Help:'),
      text.indexOf('Help dismissed'),
    );
    final compact = help.replaceAll(RegExp(r'\s+'), '');
    expect(compact, contains('Enterinsertsanewline'));
    expect(compact, contains('TabselectsEdit,FinishorInserttab'));
    expect(compact, contains('maximum5graphemes'));
    expect(compact, contains('Finishacceptsthejoinedlines'));
    expect(help.split('\n').length, greaterThan(2));
    for (final line in help.split('\n')) {
      expect(line.length, lessThanOrEqualTo(40));
    }
    expect(text, contains('Help dismissed'));
    expect(
      text.lastIndexOf('Line 1:'),
      greaterThan(text.indexOf('Help dismissed')),
    );
  });

  test('session help owns painting and restores the latest state', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    var helpBlock = '';
    var duringHelp = '';
    var afterDismissal = '';
    final result = await TerminalSession.run(
      (session) async {
        final spinner = Spinner('Upload');
        spinner.start(session: session);
        final pending = Multiline('Notes').prompt(session: session);
        await Future<void>.delayed(Duration.zero);
        input.add('ab');
        await Future<void>.delayed(Duration.zero);
        spinner.update('uploading');
        await Future<void>.delayed(Duration.zero);
        final beforeHelp = output.toString();
        input.add('\x14');
        await Future<void>.delayed(Duration.zero);
        helpBlock = output.toString().substring(beforeHelp.length);
        spinner.update('still uploading');
        await Future<void>.delayed(Duration.zero);
        duringHelp = output.toString().substring(beforeHelp.length);
        input.add('\x1b');
        // A lone escape is only distinguishable after the key decoder's
        // disambiguation delay.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        afterDismissal = output.toString().substring(beforeHelp.length);
        input.add('\t\r');
        await input.close();
        spinner.finish(FeedbackOutcome.completed);
        return await pending;
      },
      source: ScriptedInput(input.stream, output, outputProfile: _rich()),
      mode: PromptMode.rich,
    );

    expect((result as Accepted<String>).value, 'ab');
    expect(helpBlock, contains('Help:'));
    // Background updates retain their snapshot without painting into help.
    expect(duringHelp, helpBlock);
    // Dismissal restores the latest composite and repaints the draft/caret.
    expect(afterDismissal, contains('Help dismissed.'));
    expect(afterDismissal, contains('[status] Upload: still uploading'));
    expect(afterDismissal, contains('Line 1: ab'));
  });

  test('linear Multiline help is component and stage specific', () async {
    final output = StringBuffer();
    final result =
        await Multiline(
          'Notes',
          required: true,
          validate: (value) => value == 'ok' ? null : 'Enter ok',
        ).prompt(
          source: ScriptedInput(Stream.value('/help\rok\r/done\r'), output),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'ok');
    final text = output.toString();
    expect(text, contains('Help:'));
    expect(text, contains('one line per Enter'));
    expect(text, contains('/insert'));
    expect(text, contains('backslash'));
    expect(text, contains('A value is required'));
    expect(text, contains('Your validator runs'));
  });

  test(
    'a resize repaints Multiline at the new width keeping draft and caret',
    () async {
      final keys = StreamController<String>();
      var cancelled = false;
      final resized = StreamController<void>(onCancel: () => cancelled = true);
      final output = StringBuffer();
      final observer = _ResizeObserver(
        resized.stream,
        () => (columns: 12, rows: 4),
      );
      final result = Multiline('Notes', initialValue: 'abcdefgh').prompt(
        source: ScriptedInput(
          keys.stream,
          output,
          outputProfile: _rich(columns: 30),
          resizeObserver: observer,
        ),
        mode: PromptMode.rich,
      );
      await pumpEventQueue();
      // Move the logical caret off the end before the idle resize.
      for (var i = 0; i != 3; i++) {
        keys.add('\x1b[D');
      }
      await pumpEventQueue();
      final before = output.toString();
      resized.add(null);
      await pumpEventQueue();
      final after = output.toString().substring(before.length);
      expect(after, isNotEmpty);
      keys.add('X');
      keys.add('\x1b[C');
      keys.add('\x1b[C');
      keys.add('\x1b[C');
      keys.add('\t\r');
      expect((await result as Accepted<String>).value, 'abcdeXfgh');
      await pumpEventQueue();
      expect(cancelled, isTrue);
      await keys.close();
      await resized.close();
    },
  );

  test(
    'a declared rich profile drives TagInput stages and terminal leases',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value('My NewTag\r\t\r'),
          output,
          supportsRich: false,
          outputProfile: _rich(),
        ),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<List<String>>).value, ['my-new-tag']);
      expect(output.toString(), contains('Preview: my-new-tag'));

      final terminalOutput = StringBuffer();
      final terminal = _MigrationTerminal(
        Stream.value('one\r/done\r'),
        terminalOutput,
        _rich(),
      );
      final viaTerminal = await TagInput('Tags')
          .prompt(terminal: terminal, mode: PromptMode.linear);
      expect((viaTerminal as Accepted<List<String>>).value, ['one']);
      expect(terminal.events, ['acquire', 'restore']);
    },
  );

  test(
    'TagInput keeps its draft and accepted tags while feedback updates',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Upload');
          spinner.start(session: session);
          final pending = TagInput('Tags').prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add('one\r');
          await Future<void>.delayed(Duration.zero);
          input.add('two');
          await Future<void>.delayed(Duration.zero);
          final beforeUpdate = output.toString();
          spinner.update('uploading');
          await Future<void>.delayed(Duration.zero);
          // The session repaints the editor after the status write, so the
          // unaccepted draft stays visible without another keypress.
          final update = output.toString().substring(beforeUpdate.length);
          expect(update, contains('[status] Upload: uploading'));
          expect(update, contains('two'));
          input.add('\r');
          await Future<void>.delayed(Duration.zero);
          input.add('\t\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(input.stream, output, outputProfile: _rich()),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<List<String>>).value, ['one', 'two']);
    },
  );

  test('TagInput help names its stage actions and constraints', () async {
    final richOutput = StringBuffer();
    final rich = await TagInput('Tags', maxLength: 6).prompt(
      source: ScriptedInput(
        Stream.value('\x14\x1b\t\r'),
        richOutput,
        outputProfile: _rich(),
      ),
      mode: PromptMode.rich,
    );
    expect((rich as Accepted<List<String>>).value, isEmpty);
    final richText = richOutput.toString();
    expect(richText, contains('Help:'));
    expect(richText, contains('Enter adds the draft'));
    expect(richText, contains('Ctrl+X discards the draft'));
    expect(richText, contains('Maximum 6 graphemes per canonical tag'));

    final linearOutput = StringBuffer();
    final linear =
        await TagInput(
          'Tags',
          style: TagStyle.snakeCase,
          validate: (value) => value == 'bad' ? 'Not allowed' : null,
        ).prompt(
          source: ScriptedInput(Stream.value('/help\r/done\r'), linearOutput),
          mode: PromptMode.linear,
        );
    expect(linear, isA<Accepted<List<String>>>());
    final linearText = linearOutput.toString();
    expect(linearText, contains('Help:'));
    expect(linearText, contains('Enter adds one canonical snake_case tag'));
    expect(linearText, contains('/remove'));
    expect(linearText, contains('backslash'));
    expect(linearText, contains('Your validator runs on each canonical tag'));
    expect(linearText, contains('Ctrl+X discards the current draft'));
  });

  test('a resize repaints TagInput keeping draft and accepted tags', () async {
    final keys = StreamController<String>();
    var cancelled = false;
    final resized = StreamController<void>.broadcast(
      onCancel: () => cancelled = true,
    );
    final output = StringBuffer();
    final observer = _ResizeObserver(
      resized.stream,
      () => (columns: 8, rows: 4),
    );
    final result = TagInput('Tags').prompt(
      source: ScriptedInput(
        keys.stream,
        output,
        outputProfile: _rich(columns: 40),
        resizeObserver: observer,
      ),
      mode: PromptMode.rich,
    );
    await pumpEventQueue();
    keys.add('one\r');
    await pumpEventQueue();
    for (final character in 'abcdefgh'.split('')) {
      keys.add(character);
    }
    await pumpEventQueue();
    final before = output.toString();
    resized.add(null);
    await pumpEventQueue();
    final after = output.toString().substring(before.length);
    expect(after, contains('<'), reason: 'narrow width uses overflow markers');
    keys.add('\r');
    keys.add('\t\r');
    expect((await result as Accepted<List<String>>).value, ['one', 'abcdefgh']);
    await pumpEventQueue();
    expect(cancelled, isTrue);
    await keys.close();
    await resized.close();
  });

  test(
    'draft tags stay separate with canonical casing and edit/remove rules',
    () async {
      final output = StringBuffer();
      final result = await TagInput('Tags').prompt(
        source: ScriptedInput(
          Stream.value(
            'HelloWorld\r'
            'hello world\r'
            '\x7f\x7f\x7f\x7f\x7fThere\r'
            '\x7f\x1b[D\x1b[3~'
            '\t\r',
          ),
          output,
          outputProfile: _rich(),
        ),
        mode: PromptMode.rich,
      );

      // The unaccepted draft never becomes a tag, casing is canonical, a
      // duplicate leaves the accepted collection untouched, and an edit or
      // removal targets an existing tag without reordering the rest.
      expect((result as Accepted<List<String>>).value, ['hello-there']);
      final text = output.toString();
      expect(text, contains('Added: hello-world'));
      expect(text, contains('Duplicate tag; edit the draft.'));
      expect(text, contains('Preview: hello-there'));
      expect(text, contains('Focused: hello-there'));
      expect(text, contains('Removed: hello-world'));
      expect(text, contains('Added: hello-there'));
    },
  );

  test('both modes keep explicit outcomes and source invocation', () async {
    Future<PromptResult<String>> multiline(String input, PromptMode mode) =>
        Multiline('Notes').prompt(
          source: ScriptedInput(
            Stream.value(input),
            StringBuffer(),
            outputProfile: mode == PromptMode.rich
                ? _rich()
                : const OutputProfile(),
          ),
          mode: mode,
        );
    Future<PromptResult<List<String>>> tags(String input, PromptMode mode) =>
        TagInput('Tags').prompt(
          source: ScriptedInput(
            Stream.value(input),
            StringBuffer(),
            outputProfile: mode == PromptMode.rich
                ? _rich()
                : const OutputProfile(),
          ),
          mode: mode,
        );

    expect(await multiline('', PromptMode.rich), isA<InputEnded<String>>());
    expect(await multiline('', PromptMode.linear), isA<InputEnded<String>>());
    expect(await multiline('\x1bx', PromptMode.rich), isA<Cancelled<String>>());
    expect(
      await multiline('/cancel\r', PromptMode.linear),
      isA<Cancelled<String>>(),
    );
    expect(
      await multiline('\x03', PromptMode.rich),
      isA<Interrupted<String>>(),
    );
    expect(
      await multiline('\x03', PromptMode.linear),
      isA<Interrupted<String>>(),
    );
    expect(await tags('', PromptMode.rich), isA<InputEnded<List<String>>>());
    expect(await tags('', PromptMode.linear), isA<InputEnded<List<String>>>());
    expect(
      await tags('\x1bx', PromptMode.rich),
      isA<Cancelled<List<String>>>(),
    );
    expect(
      await tags('/cancel\r', PromptMode.linear),
      isA<Cancelled<List<String>>>(),
    );
    expect(
      await tags('\x03', PromptMode.rich),
      isA<Interrupted<List<String>>>(),
    );
    expect(
      await tags('\x03', PromptMode.linear),
      isA<Interrupted<List<String>>>(),
    );

    // Source invocation without a declared profile keeps working.
    expect(
      (await Multiline('Notes').prompt(
        source: ScriptedInput(Stream.value('plain\r/done\r'), StringBuffer()),
        mode: PromptMode.linear,
      ) as Accepted<String>).value,
      'plain',
    );
    expect(
      (await TagInput('Tags').prompt(
        source: ScriptedInput(Stream.value('One\r/done\r'), StringBuffer()),
        mode: PromptMode.linear,
      ) as Accepted<List<String>>).value,
      ['one'],
    );
  });
}

final class _ResizeObserver implements TerminalResizeObserver {
  _ResizeObserver(this.notifications, this._dimensions);

  @override
  final Stream<void> notifications;
  final ({int columns, int rows})? Function() _dimensions;

  @override
  ({int columns, int rows})? readDimensions() => _dimensions();

  @override
  Duration get fallbackInterval => const Duration(days: 1);
}

final class _MigrationTerminal implements TerminalIo, TerminalIoOutputProfile {
  _MigrationTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  bool get supportsRich => false;

  @override
  final Map<String, String?> environment = const {};

  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
