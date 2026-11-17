import 'dart:async';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

/// Prose help wraps inside the declared width, so phrases are compared without
/// whitespace.
String _withoutWrapping(String transcript) =>
    transcript.replaceAll(RegExp(r'\s+'), '');

final _multiSelectColors = ColorTheme(
  foreground: TerminalColor.rgb(1, 2, 3),
  background: TerminalColor.rgb(4, 5, 6),
  muted: TerminalColor.indexed(7),
  accent: TerminalColor.indexed(8),
  selectionForeground: TerminalColor.indexed(9),
  selectionBackground: TerminalColor.indexed(10),
  success: TerminalColor.indexed(11),
  warning: TerminalColor.indexed(12),
  error: TerminalColor.indexed(13),
  border: TerminalColor.indexed(14),
);

final _multiRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

void main() {
  test('rich Space changes draft and Enter submits in source order', () async {
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B \x1b[A \r'),
            StringBuffer(),
            outputProfile: _multiRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
  });
  test('linear references toggle and done submits', () async {
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B'),
        ]).prompt(
          source: ScriptedInput(Stream.value('2\r1\r/done\r'), StringBuffer()),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
  });
  test(
    'filter retains hidden choices and bulk covers all filtered pages',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('hidden', 'Other'),
        ...List.generate(12, (i) => Choice('v$i', 'Visible $i')),
        Choice('disabled', 'Visible disabled', disabledReason: 'offline'),
      ];
      final result = await MultiSelect<String>('Pick', choices).prompt(
        source: ScriptedInput(
          Stream.value(
            '1\r/filter\rVisible\r/select-visible\r/selected\r/done\r',
          ),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, [
        'hidden',
        ...List.generate(12, (i) => 'v$i'),
      ]);
      expect(out.toString(), contains('1 hidden selected'));
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
  test('maximum rejects bulk atomically and minimum preserves draft', () async {
    final out = StringBuffer();
    final result =
        await MultiSelect<String>(
          'Pick',
          [Choice('a', 'A'), Choice('b', 'B'), Choice('c', 'C')],
          min: 2,
          max: 2,
        ).prompt(
          source: ScriptedInput(
            Stream.value('1\r/done\r/select-visible\r2\r/done\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<List<String>>).value, ['a', 'b']);
    expect(out.toString(), contains('Minimum 2'));
    expect(out.toString(), contains('no changes made'));
  });
  test('empty is an accepted result', () async {
    final result = await MultiSelect<String>('Pick', []).prompt(
      source: ScriptedInput(Stream.value('/done\r'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<List<String>>).value, isEmpty);
  });
  test('supplied references are literal, validated and ordered', () async {
    final prompt = MultiSelect<String>(
      'Pick',
      [
        Choice('a', 'Same'),
        Choice('b', 'Same'),
        Choice('c', 'C', disabledReason: 'offline'),
      ],
      min: 1,
      max: 2,
    );
    expect(
      (await prompt.prompt(
        source: SuppliedAnswer('2,1'),
      ) as Accepted<List<String>>).value,
      ['a', 'b'],
    );
    for (final input in ['', '1,1', '3', '4', '/cancel', '1,2,3']) {
      expect(
        await prompt.prompt(source: SuppliedAnswer(input)),
        isA<Unavailable<List<String>>>(),
      );
    }
    final empty = await MultiSelect<String>(
      'Pick',
      [],
    ).prompt(source: SuppliedAnswer(''));
    expect((empty as Accepted<List<String>>).value, isEmpty);
  });
  test(
    'clear visible removes only enabled filtered selections across pages',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('hidden', 'Other'),
        ...List.generate(12, (i) => Choice('v$i', 'Visible $i')),
        Choice('disabled', 'Visible disabled', disabledReason: 'offline'),
      ];
      final result =
          await MultiSelect<String>(
            'Pick',
            choices,
            defaultValues: ['hidden', ...List.generate(12, (i) => 'v$i')],
          ).prompt(
            source: ScriptedInput(
              Stream.value(
                '/filter\rVisible\r/clear-visible\r/selected\r/done\r',
              ),
              out,
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<List<String>>).value, ['hidden']);
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
  test(
    'stable references identify duplicate labels through paging and filters',
    () async {
      final out = StringBuffer();
      final choices = [
        Choice('a', 'Same'),
        ...List.generate(10, (i) => Choice('x$i', 'Other $i')),
        Choice('b', 'Same'),
      ];
      final result = await MultiSelect<String>('Pick', choices).prompt(
        source: ScriptedInput(
          Stream.value('/next\r12\r/filter\rSame\r1\r/selected\r/done\r'),
          out,
        ),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      expect(out.toString(), contains('12. Same'));
      expect(out.toString(), contains('Page 2 of 2'));
    },
  );
  test('disabled focus is inspectable but cannot toggle', () async {
    final out = StringBuffer();
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B', disabledReason: 'offline'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B \r'),
            out,
            outputProfile: _multiRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, isEmpty);
    expect(out.toString(), contains('[focused] [unavailable: offline]'));
    expect(out.toString(), contains('Unavailable: offline'));
  });
  test('cancellation interruption and EOF never accept a draft', () async {
    final prompt = MultiSelect<String>('Pick', [Choice('a', 'A')]);
    for (final scenario in [
      (PromptMode.rich, ' \x1bx', 0),
      (PromptMode.rich, ' \x03', 1),
      (PromptMode.rich, ' ', 2),
      (PromptMode.linear, '1\r/cancel\r', 0),
      (PromptMode.linear, '1\r', 2),
    ]) {
      final result = await prompt.prompt(
        source: ScriptedInput(
          Stream.value(scenario.$2),
          StringBuffer(),
          outputProfile: scenario.$1 == PromptMode.rich
              ? _multiRichProfile
              : const OutputProfile(),
        ),
        mode: scenario.$1,
      );
      if (scenario.$3 == 0) expect(result, isA<Cancelled<List<String>>>());
      if (scenario.$3 == 1) expect(result, isA<Interrupted<List<String>>>());
      if (scenario.$3 == 2) expect(result, isA<InputEnded<List<String>>>());
    }
  });
  test(
    'rich requirement and automatic fallback are distinct outcomes',
    () async {
      final prompt = MultiSelect<String>('Pick', [Choice('a', 'A')]);
      expect(
        await prompt.prompt(
          source: ScriptedInput(const Stream<String>.empty(), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<List<String>>>(),
      );
      expect(
        (await prompt.prompt(
          source: ScriptedInput(Stream.value('1\r/done\r'), StringBuffer()),
          mode: PromptMode.automatic,
        ) as Accepted<List<String>>).value,
        ['a'],
      );
    },
  );

  test(
    'toggles, reviews and bounds respect declared width and colour',
    () async {
      // The shared editor's own status lines need 34 columns; the component's
      // rows, filters and feedback must still wrap inside this width.
      const columns = 40;
      final out = StringBuffer();
      final result =
          await MultiSelect<String>(
            'Pick',
            [
              Choice('a', 'A much longer choice label'),
              Choice('b', 'B', disabledReason: 'offline'),
              Choice('c', 'C'),
            ],
            max: 1,
            colors: _multiSelectColors,
          ).prompt(
            source: ScriptedInput(
              Stream.value('2\r2\r1\r3\r/selected\r/done\r'),
              out,
              outputProfile: OutputProfile(
                cursor: CapabilitySupport.supported,
                colorDepth: ColorDepth.rgb,
                geometry: OutputGeometry.fixed(columns: columns, rows: 24),
              ),
            ),
            mode: PromptMode.linear,
          );
      expect((result as Accepted<List<String>>).value, ['a']);
      final transcript = out.toString();
      final plain = transcript.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
      for (final line in plain.split('\n')) {
        expect(
          line.length,
          lessThanOrEqualTo(columns),
          reason: 'line exceeds declared width: "$line"',
        );
      }
      // Repeated rejections each explain the reason; the bound is explicit.
      expect(RegExp('Unavailable: offline').allMatches(plain).length, 2);
      expect(RegExp('Maximum 1 selections').allMatches(plain).length, 1);
      expect(
        _withoutWrapping(plain),
        contains('Amuchlongerchoicelabel:checked.'),
      );
      expect(
        transcript,
        contains('\x1b[38;5;12;48;2;4;5;6mUnavailable: offline'),
      );
      expect(transcript, contains('\x1b[38;5;12;48;2;4;5;6mMaximum 1'));
    },
  );

  test('linear help names selection commands, bounds and reasons', () async {
    final out = StringBuffer();
    await MultiSelect<String>(
      'Pick',
      [Choice('a', 'A'), Choice('b', 'B', disabledReason: 'offline')],
      min: 1,
      max: 2,
    ).prompt(
      source: ScriptedInput(Stream.value('/help\r'), out),
      mode: PromptMode.linear,
    );
    final transcript = out.toString();
    for (final advertised in [
      '/done',
      '/selected',
      '/filter',
      '/select-visible',
      '/clear-visible',
      '/next',
      '/previous',
    ]) {
      expect(transcript, contains(advertised));
    }
    expect(
      _withoutWrapping(transcript),
      contains('2.Bisunavailable(offline)andcannotbetoggled'),
    );
    expect(transcript, contains('minimum 1'));
    expect(transcript, contains('maximum 2'));
  });

  test('rich help describes toggling, review and restores the draft', () async {
    final out = StringBuffer();
    final result =
        await MultiSelect<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B', disabledReason: 'offline'),
        ], max: 1).prompt(
          source: ScriptedInput(
            Stream.value(' \x14\x1b\r'),
            out,
            outputProfile: _multiRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<List<String>>).value, ['a']);
    final transcript = out.toString();
    final help = _withoutWrapping(transcript);
    expect(help, contains('Spacetoggles'));
    expect(help, contains('Ctrl+Aselectsvisible'));
    expect(help, contains('Ctrl+Xclearsvisible'));
    expect(help, contains('Ctrl+Rreviews'));
    expect(help, contains('Escapedismisseshelporcancels'));
    expect(help, contains('2.Bisunavailable(offline)andcannotbetoggled'));
    // Help dismissal repaints the retained checked draft and focus.
    expect(
      transcript.lastIndexOf('1. A [checked] [focused]'),
      greaterThan(transcript.indexOf('Help:')),
    );
  });

  test(
    'wrapped multi-select rows keep state markers intact and in order',
    () async {
      const columns = 24;
      final out = StringBuffer();
      final result =
          await MultiSelect<String>(
            'Pick',
            [Choice('a', 'ABCDEFGHIJKLMNOPQRS'), Choice('b', 'B')],
            defaultValues: ['a'],
          ).prompt(
            source: ScriptedInput(
              Stream.value('\r'),
              out,
              outputProfile: OutputProfile(
                cursor: CapabilitySupport.supported,
                geometry: OutputGeometry.fixed(columns: columns, rows: 24),
              ),
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['a']);
      final transcript = out.toString();
      final rows = transcript
          .split('\n')
          .where((line) => line.startsWith('1. '))
          .toList();
      expect(rows, isNotEmpty);
      for (final line in rows) {
        expect(
          line.length,
          lessThanOrEqualTo(columns),
          reason: 'row exceeds declared width: "$line"',
        );
      }
      expect(transcript, contains('1. ABCDEFGHIJKLMNOPQRS'));
      expect(transcript, contains('[checked]'));
      expect(transcript, contains('[focused]'));
      expect(transcript, contains('[default]'));
      expect(
        transcript.indexOf('[checked]'),
        lessThan(transcript.indexOf('[focused]')),
      );
      expect(
        transcript.indexOf('[focused]'),
        lessThan(transcript.indexOf('[default]')),
      );
    },
  );
  test('invalid defaults and count constraints are rejected', () {
    final choices = [
      Choice('a', 'A'),
      Choice('b', 'B', disabledReason: 'offline'),
    ];
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['b']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['a', 'a']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, defaultValues: ['missing']),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', choices, min: 2, max: 1),
      throwsArgumentError,
    );
    expect(
      () => MultiSelect('Pick', [Choice('a', 'A'), Choice('a', 'B')]),
      throwsArgumentError,
    );
  });
  test('linear instructions explain literal command quoting', () async {
    final out = StringBuffer();
    await MultiSelect<String>('Pick', []).prompt(
      source: ScriptedInput(Stream.value('/done\r'), out),
      mode: PromptMode.linear,
    );
    expect(out.toString(), contains('Quote commands with a backslash'));
    expect(out.toString(), contains('Identified paste is literal'));
  });
  test(
    'a multi-select prompt retains its draft while session feedback updates',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      final profile = OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 80, rows: 24),
      );

      final result = await TerminalSession.run(
        (session) async {
          final spinner = Spinner('Index');
          spinner.start(session: session);
          final pending = MultiSelect<String>('Pick', [
            Choice('a', 'A'),
          ]).prompt(session: session);
          await Future<void>.delayed(Duration.zero);
          input.add(' ');
          await Future<void>.delayed(Duration.zero);
          spinner.update('refreshing');
          input.add('\r');
          await input.close();
          spinner.finish(FeedbackOutcome.completed);
          return await pending;
        },
        source: ScriptedInput(input.stream, output, outputProfile: profile),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<List<String>>).value, ['a']);
      final transcript = output.toString();
      expect(transcript, contains('[status] Index: refreshing'));
      expect(transcript, contains('A [checked]'));
      expect(
        transcript.lastIndexOf('A [checked]'),
        greaterThan(transcript.indexOf('[status] Index: refreshing')),
      );
    },
  );
  test(
    'rich filtering retains hidden draft and bulk enforces maximum atomically',
    () async {
      final out = StringBuffer();
      final result =
          await MultiSelect<String>('Pick', [
            Choice('a', 'Other'),
            Choice('b', 'Visible B'),
            Choice('c', 'Visible C'),
          ], max: 2).prompt(
            source: ScriptedInput(
              Stream.value(' /Visible\r\x01\x12 \r'),
              out,
              outputProfile: _multiRichProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<List<String>>).value, ['a', 'b']);
      expect(out.toString(), contains('1 hidden selected'));
      expect(out.toString(), contains('no changes made'));
      expect(out.toString(), contains('1. Other [hidden]'));
    },
  );
}
