import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/theme_choice_components.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a themed select renders focus, selection, default and restrictions apart',
    () async {
      final output = StringBuffer();
      final prompt = ThemeSingleChoicePrompt<String>.select(
        'Pick',
        [
          ThemeChoiceOption('a', 'Alpha', lockedReason: 'needs owner role'),
          ThemeChoiceOption('b', 'Beta', selected: true),
          ThemeChoiceOption('c', 'Gamma', unavailableReason: 'offline'),
        ],
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[B\r'),
          output: output,
          profile: _richProfile,
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        defaultValue: 'a',
        selectionStyle: SingleSelectionStyle.squares,
      );

      final result = await prompt.prompt();

      expect((result as Accepted<String>).value, 'b');
      final text = output.toString();
      expect(
        text,
        contains('■'),
        reason: 'selected state uses the configured style',
      );
      expect(
        text,
        contains('□'),
        reason: 'unselected rows have their own glyph',
      );
      expect(text, contains('→'), reason: 'focus is independent of selection');
      expect(
        text,
        contains('★'),
        reason: 'default is independent of selection',
      );
      expect(
        text,
        contains('[L]'),
        reason: 'locked choices carry a visible marker',
      );
      expect(text, contains('needs owner role'));
      expect(
        text,
        contains('[!]'),
        reason: 'unavailable choices carry a visible marker',
      );
      expect(text, contains('offline'));
    },
  );
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 60, rows: 14),
);
