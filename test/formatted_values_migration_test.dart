import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  colorDepth: ColorDepth.indexed256,
  geometry: OutputGeometry.fixed(columns: 100, rows: 30),
);

final _palette = ColorThemes.terminalDefault.copyWith(
  foreground: TerminalColor.indexed(12),
);

void main() {
  const clearHelpCommand = '\x01\x1b[3~\x1b[3~\x1b[3~\x1b[3~\x1b[3~';

  test(
    'formatted inputs forward compact guidance, help, and palette settings',
    () async {
      final inputs = <Future<PromptResult<Object?>> Function(StringBuffer)>[
        (out) =>
            NumberInput(
              'Number',
              convention: NumericConvention.ascii(),
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['number detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r${clearHelpCommand}12\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
        (out) =>
            PortInput(
              'Port',
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['port detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r${clearHelpCommand}443\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
        (out) =>
            IPAddressInput(
              'Address',
              cidr: true,
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['address detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r${clearHelpCommand}192.0.2.7/24\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
        (out) =>
            EmailInput(
              'Email',
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['email detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r${clearHelpCommand}x@example.com\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
        (out) =>
            ColorInput(
              'Color',
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['color detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r$clearHelpCommand#f00\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
        (out) =>
            DurationInput(
              'Duration',
              durationMode: DurationInputMode.elapsed,
              instructions: InstructionDisplay.hidden,
              supplementaryHelp: const ['duration detail'],
              colors: _palette,
            ).prompt(
              source: ScriptedInput(
                Stream.value('/help\r${clearHelpCommand}1s\r'),
                out,
              ),
              mode: PromptMode.linear,
              outputProfile: _richProfile,
            ),
      ];

      for (final input in inputs) {
        final output = StringBuffer();
        expect(
          await input(output),
          isA<Accepted<Object?>>(),
          reason: output.toString(),
        );
        expect(output.toString(), contains('detail'));
        expect(output.toString(), isNot(contains('Left/Right move')));
        expect(output.toString(), contains('\x1b[38;5;12;49m'));
      }
    },
  );

  test(
    'formatted inputs inherit a shared rich session configuration',
    () async {
      final output = StringBuffer();
      final result = await TerminalSession.run(
        (session) => PortInput('Port').prompt(session: session),
        source: ScriptedInput(
          Stream.value('443\r'),
          output,
          outputProfile: _richProfile,
        ),
        mode: PromptMode.rich,
      );

      expect((result as Accepted<int>).value, 443);
      expect(output.toString(), contains('ASCII decimal'));
    },
  );
}
