import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/double_theme_internal.dart';
import 'package:trelis/trelis.dart';

OutputProfile _profile({
  bool ascii = false,
  ColorDepth depth = ColorDepth.rgb,
  int columns = 72,
}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: columns, rows: 20),
  glyphs: ascii ? GlyphSet.ascii : GlyphSet.unicode,
  colorDepth: depth,
);

String _foreground(DoubleRgb rgb) =>
    '\x1b[38;2;${rgb.red};${rgb.green};${rgb.blue};49m';

void main() {
  test(
    'Double text input renders the authored light palette on RGB output',
    () async {
      final output = StringBuffer();
      final theme = DoubleInternalPresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('Ada\r'),
          output: output,
          profile: _profile(),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.light),
      );

      final result = await theme.textInput('Project name');

      expect((result as Accepted<String>).value, 'Ada');
      final text = output.toString();
      expect(
        text,
        contains(
          _foreground(
            DoublePaletteDefaults.lightRgb[DoublePaletteRole.foreground]!,
          ),
        ),
      );
      expect(
        text,
        isNot(
          contains(
            _foreground(
              DoublePaletteDefaults.darkRgb[DoublePaletteRole.foreground]!,
            ),
          ),
        ),
      );
      expect(text, contains('╔'));
      expect(text, contains('╚'));
    },
  );
}
