import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/trelis.dart';

void main() {
  final themes = <String, StructuralTheme Function(TerminalEnvironment)>{
    'ascii': (io) => AsciiTheme(io: io),
    'block': (io) => BlockTheme(io: io),
    'box': (io) => BoxTheme(io: io),
    'bracket': (io) => BracketTheme(io: io),
    'branch': (io) => BranchTheme(io: io),
    'chevron': (io) => ChevronTheme(io: io),
    'colon': (io) => ColonTheme(io: io),
    'double': (io) => DoubleTheme(io: io),
    'form': (io) => FormTheme(io: io),
    'ledger': (io) => LedgerTheme(io: io),
    'line': (io) => LineTheme(io: io),
    'minimal': (io) => MinimalTheme(io: io),
    'plain': (io) => PlainTheme(io: io),
    'rail': (io) => RailTheme(io: io),
    'round': (io) => RoundTheme(io: io),
  };

  for (final entry in themes.entries) {
    test('${entry.key} emits colour with an observed native profile', () async {
      final output = StringBuffer();
      final io = TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: output,
        profile: TerminalEnvironment.nativeProfile(
          hasTerminal: true,
          supportsRich: false,
          windowsTerminal: true,
        ),
      );

      final result = await entry
          .value(io)
          .textInput(
            'Deployment target',
            colors: ComponentColors.palette(ColorThemes.signal),
          )
          .prompt();

      expect(
        result,
        isA<Accepted<String>>().having((r) => r.value, 'answer', 'Ada'),
      );
      expect(output.toString(), contains('\x1b[38;2;'));
      expect(output.toString(), isNot(contains('<ESC>')));
      expect(output.toString(), isNot(contains(r'\e[')));
    });
  }

  for (final restricted in ['redirected', 'NO_COLOR', 'dumb', 'unknown']) {
    test(
      '$restricted output remains colourless with an explicit palette',
      () async {
        final output = StringBuffer();
        final profile = TerminalEnvironment.nativeProfile(
          hasTerminal: restricted != 'redirected',
          supportsRich: false,
          term: restricted == 'dumb' ? 'dumb' : '',
          windowsTerminal: restricted != 'unknown',
          colorDisabled: restricted == 'NO_COLOR',
        );
        final io = TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: output,
          profile: profile,
          environment: {if (restricted == 'NO_COLOR') 'NO_COLOR': '1'},
        );

        final result = await AsciiTheme(io: io)
            .textInput(
              'Deployment target',
              colors: ComponentColors.palette(ColorThemes.signal),
            )
            .prompt();

        expect(result, isA<Accepted<String>>());
        expect(output.toString(), isNot(contains('\x1b[')));
      },
    );
  }
}
