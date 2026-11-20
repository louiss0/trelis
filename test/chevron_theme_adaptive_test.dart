import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/chevron_theme_internal.dart';
import 'package:trelis/trelis.dart';

double _relativeLuminance(ChevronRgb rgb) {
  double channel(int value) {
    final scaled = value / 255;
    return scaled <= 0.04045
        ? scaled / 12.92
        : math.pow((scaled + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(rgb.red) +
      0.7152 * channel(rgb.green) +
      0.0722 * channel(rgb.blue);
}

double _contrast(ChevronRgb first, ChevronRgb second) {
  final a = _relativeLuminance(first);
  final b = _relativeLuminance(second);
  final high = a > b ? a : b;
  final low = a < b ? a : b;
  return (high + 0.05) / (low + 0.05);
}

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

String _foreground(ChevronRgb rgb) =>
    '\x1b[38;2;${rgb.red};${rgb.green};${rgb.blue};49m';

List<String> _lines(String text) => text
    .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
    .replaceAll('\r', '')
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .toList();

void main() {
  test('authored normal-text pairs meet the reference contrast target', () {
    for (final reference in [
      (
        name: 'Atelier Sepia light',
        background: ChevronPaletteDefaults.lightReferenceBackground,
        roles: ChevronPaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: ChevronPaletteDefaults.darkReferenceBackground,
        roles: ChevronPaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        ChevronPaletteRole.foreground,
        ChevronPaletteRole.muted,
        ChevronPaletteRole.accent,
        ChevronPaletteRole.success,
        ChevronPaletteRole.warning,
        ChevronPaletteRole.error,
        ChevronPaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[ChevronPaletteRole.selectionForeground]!,
        reference.roles[ChevronPaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });

  test(
    'Chevron text input renders the authored light palette on RGB output',
    () async {
      final output = StringBuffer();
      final theme = ChevronInternalPresentation(
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
            ChevronPaletteDefaults.lightRgb[ChevronPaletteRole.foreground]!,
          ),
        ),
      );
      expect(
        text,
        isNot(
          contains(
            _foreground(
              ChevronPaletteDefaults.darkRgb[ChevronPaletteRole.foreground]!,
            ),
          ),
        ),
      );
      expect(text, contains('\u276f'));
      expect(text, contains('\u21b3'));
    },
  );

  test(
    'Chevron selection keeps its heading, rows and help under the dark heading',
    () async {
      final output = StringBuffer();
      final theme = ChevronInternalPresentation(
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
            ChevronPaletteDefaults.darkRgb[ChevronPaletteRole.foreground]!,
          ),
        ),
      );
      expect(
        text,
        isNot(
          contains(
            _foreground(
              ChevronPaletteDefaults.lightRgb[ChevronPaletteRole.foreground]!,
            ),
          ),
        ),
      );

      final lines = _lines(text);
      expect(lines.first, startsWith('\u276f '));
      expect(lines.first, contains('Features'));
      final starter = lines.indexWhere((line) => line.contains('Starter'));
      final library = lines.indexWhere((line) => line.contains('Library'));
      final help = lines.indexWhere(
        (line) => line.contains('Up/Down navigate'),
      );
      expect(starter, greaterThan(0));
      expect(library, greaterThan(starter));
      expect(help, greaterThan(library));
      expect(lines[help], contains('\u21b3'));
      expect(lines[help], contains('Ctrl+T'));
      expect(text, isNot(contains('\u2550')));
    },
  );
}
