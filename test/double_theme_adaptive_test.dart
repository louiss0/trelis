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

List<String> _lines(String text) => text
    .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
    .replaceAll('\r', '')
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .toList();

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

  test(
    'Double selection keeps its title, rows and help in the dark enclosure',
    () async {
      final output = StringBuffer();
      final theme = DoubleInternalPresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('\r'),
          output: output,
          profile: _profile(),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );

      final result = await theme.select<String>('Features', [
        Choice('starter', 'Starter'),
        Choice('library', 'Library'),
      ], defaultValue: 'library');

      expect((result as Accepted<String>).value, 'library');
      final text = output.toString();
      expect(
        text,
        contains(
          _foreground(
            DoublePaletteDefaults.darkRgb[DoublePaletteRole.foreground]!,
          ),
        ),
      );
      expect(
        text,
        isNot(
          contains(
            _foreground(
              DoublePaletteDefaults.lightRgb[DoublePaletteRole.foreground]!,
            ),
          ),
        ),
      );

      final lines = _lines(text);
      expect(lines.first, startsWith('╔'));
      expect(lines.first, endsWith('╗'));
      final body = lines.where((line) => line.startsWith('║')).toList();
      expect(body, hasLength(greaterThanOrEqualTo(3)));
      expect(body.first, contains('Features'));
      expect(
        lines.any((line) => line.startsWith('║') && line.contains('Starter')),
        isTrue,
      );
      expect(
        lines.any((line) => line.startsWith('║') && line.contains('Library')),
        isTrue,
      );
      final bottom = lines.lastIndexWhere(
        (line) => line.startsWith('╚') && line.endsWith('╝'),
      );
      expect(bottom, greaterThan(0));
      final afterFrame = lines.skip(bottom + 1).join(' ');
      expect(afterFrame, contains('Up/Down navigate'));
      expect(afterFrame, contains('Ctrl+T'));
      expect(afterFrame.replaceAll(RegExp(r'\s'), ''), contains('help'));
      expect(text, isNot(contains('┌')));
    },
  );
}
