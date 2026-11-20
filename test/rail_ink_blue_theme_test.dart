import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/rail_ink_blue_theme.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'a light rail text input renders the authored ink-blue palette',
    () async {
      final output = StringBuffer();
      final theme = RailInkBlueTheme(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: output,
          profile: _profile(),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        colors: const ColorPreferences(background: BackgroundPreference.light),
      );

      final result = await theme.textInput('Project name');

      expect((result as Accepted<String>).value, 'Ada');
      final text = output.toString();
      expect(text, contains('| Project name'));
      expect(text, contains('\x1b[38;2;47;53;66;49m| Project name'));
      expect(text, contains('/help'));
      expect(text, contains(r'\ '));
      expect(text, isNot(contains('\x1b[48;2')));
    },
  );
}

OutputProfile _profile() => OutputProfile(
  colorDepth: ColorDepth.rgb,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: 60, rows: 20),
);
