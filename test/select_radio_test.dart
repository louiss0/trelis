import 'dart:async';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Select navigation is provisional and Enter accepts focused identity',
    () async {
      final output = StringBuffer();
      final result =
          await Select<String>('Pick', [
            Choice('a', 'Same'),
            Choice('b', 'Same'),
          ]).prompt(
            source: ScriptedInput(
              Stream.value('\x1b[B\r'),
              output,
              outputProfile: _selectionRichProfile,
            ),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'b');
      expect(output.toString(), contains('focused'));
    },
  );
  test(
    'linear help advertises paging rather than unrelated commands',
    () async {
      final output = StringBuffer();
      await Radio<String>('Pick', [Choice('a', 'A')]).prompt(
        source: ScriptedInput(Stream.value('/help\r/cancel\r'), output),
        mode: PromptMode.linear,
      );
      expect(output.toString(), isNot(contains('/list')));
      expect(output.toString(), contains('/next'));
    },
  );
  test('disabled default stays focused and cannot be accepted', () async {
    final out = StringBuffer();
    final result =
        await Radio<String>('Pick', [
          Choice('a', 'A', disabledReason: 'offline'),
          Choice('b', 'B'),
        ], defaultValue: 'a').prompt(
          source: ScriptedInput(
            Stream.value('\r\x1b[B\r'),
            out,
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'b');
    expect(
      out.toString(),
      contains('[focused] [default] [unavailable: offline]'),
    );
    expect(out.toString(), contains('Unavailable: offline'));
  });
  test(
    'first enabled focus, boundaries and provisional cancellation',
    () async {
      final choices = [
        Choice('a', 'A', disabledReason: 'offline'),
        Choice('b', 'B'),
      ];
      final out = StringBuffer();
      final prompt = Select<String>('Pick', choices);
      expect(
        (await prompt.prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\r'),
            out,
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        ) as Accepted<String>).value,
        'b',
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(
            Stream.value('\x1b[A'),
            StringBuffer(),
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<String>>(),
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(
            Stream.value('\x03'),
            StringBuffer(),
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<Interrupted<String>>(),
      );
      expect(
        await prompt.prompt(
          source: ScriptedInput(Stream.value('/cancel\r'), StringBuffer()),
          mode: PromptMode.linear,
        ),
        isA<Cancelled<String>>(),
      );
    },
  );
  test('linear paging retains references despite duplicate labels', () async {
    final out = StringBuffer();
    final choices = List.generate(12, (i) => Choice('id$i', 'Same'));
    final result = await Select<String>('Pick', choices).prompt(
      source: ScriptedInput(Stream.value('/next\r12\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, 'id11');
    expect(out.toString(), contains('Page 2 of 2'));
    expect(out.toString(), contains('12. Same'));
  });
  test('missing defaults and duplicate identities are rejected', () {
    expect(
      () => Select<String>('Pick', [Choice('a', 'A')], defaultValue: 'missing'),
      throwsArgumentError,
    );
    expect(
      () => Radio<String>('Pick', [Choice('a', 'A'), Choice('a', 'B')]),
      throwsArgumentError,
    );
  });
  test('empty and all unavailable lists cannot submit', () async {
    for (final choices in <List<Choice<String>>>[
      [],
      [Choice('a', 'A', disabledReason: 'offline')],
    ]) {
      final out = StringBuffer();
      expect(
        await Select<String>('Pick', choices).prompt(
          source: ScriptedInput(
            Stream.value('\r'),
            out,
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        ),
        isA<InputEnded<String>>(),
      );
      expect(
        out.toString(),
        anyOf(
          contains('No choice available'),
          contains('Unavailable: offline'),
        ),
      );
    }
  });

  test('linear help retains references, paging commands and reasons', () async {
    final out = StringBuffer();
    final choices = [
      ...List.generate(11, (i) => Choice('id$i', 'Choice $i')),
      Choice('id11', 'Later', disabledReason: 'offline'),
    ];
    await Select<String>('Pick', choices, defaultValue: 'id5').prompt(
      source: ScriptedInput(Stream.value('/help\r/cancel\r'), out),
      mode: PromptMode.linear,
    );
    final transcript = out.toString();
    expect(transcript, contains('stable choice number'));
    expect(transcript, contains('/next'));
    expect(transcript, contains('/previous'));
    expect(transcript, contains('/help'));
    expect(transcript, contains('/cancel'));
    // The reason stays reviewable even though its page is not displayed.
    expect(
      _withoutWrapping(transcript),
      contains('12.Laterisunavailable(offline)andcannotbeaccepted'),
    );
    expect(transcript, contains('Default: 6. Choice 5'));
    expect(transcript, isNot(contains('/select-visible')));
  });

  test('rich help describes every control and restores the draft', () async {
    final out = StringBuffer();
    final result =
        await Select<String>('Pick', [
          Choice('a', 'A'),
          Choice('b', 'B', disabledReason: 'offline'),
          Choice('c', 'C'),
        ]).prompt(
          source: ScriptedInput(
            Stream.value('\x1b[B\x14\x1b\r\x1b[B\r'),
            out,
            outputProfile: _selectionRichProfile,
          ),
          mode: PromptMode.rich,
        );
    expect((result as Accepted<String>).value, 'c');
    final transcript = out.toString();
    final help = _withoutWrapping(transcript);
    expect(help, contains('Up/Downmovethefocus'));
    expect(help, contains('Escapedismisseshelporcancels'));
    expect(help, contains('Ctrl+Cinterrupts'));
    expect(help, contains('2.Bisunavailable(offline)andcannotbeaccepted'));
    // Help dismissal repaints the retained focus and its reason.
    expect(
      transcript.lastIndexOf('2. B [focused] [unavailable: offline]'),
      greaterThan(transcript.indexOf('Help:')),
    );
    expect(transcript, contains('Unavailable: offline'));
  });

  test(
    'supplied answers, rich requirement and fallback are distinct',
    () async {
      final prompt = Select<int>('Pick', [
        Choice(1, 'One'),
        Choice(2, 'Two', disabledReason: 'offline'),
      ]);
      expect(
        (await prompt.prompt(
          source: SuppliedAnswer('1'),
        ) as Accepted<int>).value,
        1,
      );
      for (final supplied in ['0', '3', '2', '', 'One']) {
        expect(
          await prompt.prompt(source: SuppliedAnswer(supplied)),
          isA<Unavailable<int>>(),
          reason: 'supplied reference "$supplied" must not be accepted',
        );
      }
      expect(
        await prompt.prompt(
          source: ScriptedInput(const Stream<String>.empty(), StringBuffer()),
          mode: PromptMode.rich,
        ),
        isA<Unavailable<int>>(),
      );
      expect(
        (await prompt.prompt(
          source: ScriptedInput(Stream.value('1\r'), StringBuffer()),
          mode: PromptMode.automatic,
        ) as Accepted<int>).value,
        1,
      );
    },
  );

  test('rejections and acceptance respect declared width and colour', () async {
    // The shared editor's own status lines need 34 columns; the component's
    // guidance, rows and feedback must still wrap inside this width.
    const columns = 40;
    final out = StringBuffer();
    final result =
        await Select<String>('Pick', [
          Choice('a', 'A', disabledReason: 'offline'),
          Choice('b', 'A much longer choice label'),
        ], colors: _selectionColors).prompt(
          source: ScriptedInput(
            Stream.value('1\r\r\x7f2\r'),
            out,
            outputProfile: OutputProfile(
              cursor: CapabilitySupport.supported,
              colorDepth: ColorDepth.rgb,
              geometry: OutputGeometry.fixed(columns: columns, rows: 24),
            ),
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, 'b');
    final transcript = out.toString();
    final plain = transcript.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
    for (final line in plain.split('\n')) {
      expect(
        line.length,
        lessThanOrEqualTo(columns),
        reason: 'line exceeds declared width: "$line"',
      );
    }
    // Repeated rejections each explain the same protected reason.
    expect(
      RegExp('Chooseanenabledreference')
          .allMatches(_withoutWrapping(plain))
          .length,
      2,
    );
    expect(plain, contains('Accepted:'));
    expect(
      _withoutWrapping(plain),
      contains('Accepted:Amuchlongerchoicelabel.'),
    );
    // Feedback uses the component palette when the profile allows colour.
    expect(
      transcript,
      contains('\x1b[38;5;12;48;2;4;5;6mUnavailable: offline'),
    );
    expect(transcript, contains('\x1b[38;5;11;48;2;4;5;6mAccepted: A much'));
  });

  test('wrapped choice rows keep state markers intact and in order', () async {
    const columns = 24;
    final out = StringBuffer();
    final result =
        await Select<String>('Pick', [
          Choice('a', 'ABCDEFGHIJKLMNOPQRS'),
          Choice('b', 'B'),
        ], defaultValue: 'a').prompt(
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
    expect((result as Accepted<String>).value, 'a');
    final transcript = out.toString();
    final row = transcript
        .split('\n')
        .where((line) => line.startsWith('1. '))
        .toList();
    expect(row, isNotEmpty);
    for (final line in row) {
      expect(
        line.length,
        lessThanOrEqualTo(columns),
        reason: 'row exceeds declared width: "$line"',
      );
    }
    expect(transcript, contains('1. ABCDEFGHIJKLMNOPQRS'));
    expect(transcript, contains('[focused]'));
    expect(transcript, contains('[default]'));
    expect(
      transcript.indexOf('[focused]'),
      lessThan(transcript.indexOf('[default]')),
    );
  });

  test('single-choice prompts forward profiles and terminal leases', () async {
    final profile = OutputProfile(
      cursor: CapabilitySupport.supported,
      colorDepth: ColorDepth.rgb,
      geometry: OutputGeometry.fixed(columns: 80, rows: 24),
    );
    final output = StringBuffer();
    final terminal = _SelectionTerminal(Stream.value('\r'), output, profile);

    final result = await Select<String>(
      'Pick',
      [Choice('a', 'A')],
      colors: _selectionColors,
    ).prompt(terminal: terminal, mode: PromptMode.rich);

    expect((result as Accepted<String>).value, 'a');
    expect(terminal.events, ['acquire', 'restore']);
    expect(output.toString(), contains('\x1b[38;2;1;2;3;48;2;4;5;6m'));
  });
}

/// Prose help wraps inside the declared width, so phrases are compared without
/// whitespace.
String _withoutWrapping(String transcript) =>
    transcript.replaceAll(RegExp(r'\s+'), '');

final _selectionRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

final _selectionColors = ColorTheme(
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

final class _SelectionTerminal implements TerminalIo, TerminalIoOutputProfile {
  _SelectionTerminal(this.input, this.output, this.outputProfile);

  @override
  final Stream<String> input;

  @override
  final StringSink output;

  @override
  final OutputProfile outputProfile;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const {};

  final List<String> events = [];

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}
