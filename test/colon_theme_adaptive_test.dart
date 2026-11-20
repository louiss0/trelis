import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/colon_theme_internal.dart';
import 'package:trelis/trelis.dart';

double _relativeLuminance(ColonRgb rgb) {
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

double _contrast(ColonRgb first, ColonRgb second) {
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

String _foreground(ColonRgb rgb) =>
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
        background: ColonPaletteDefaults.lightReferenceBackground,
        roles: ColonPaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: ColonPaletteDefaults.darkReferenceBackground,
        roles: ColonPaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        ColonPaletteRole.foreground,
        ColonPaletteRole.muted,
        ColonPaletteRole.accent,
        ColonPaletteRole.success,
        ColonPaletteRole.warning,
        ColonPaletteRole.error,
        ColonPaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[ColonPaletteRole.selectionForeground]!,
        reference.roles[ColonPaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });

  test('Colon selection keeps typed labels and compact help under the dark heading', () async {
    final output = StringBuffer();
    final theme = ColonInternalPresentation(
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
        _foreground(ColonPaletteDefaults.darkRgb[ColonPaletteRole.foreground]!),
      ),
    );
    expect(
      text,
      isNot(
        contains(
          _foreground(
            ColonPaletteDefaults.lightRgb[ColonPaletteRole.foreground]!,
          ),
        ),
      ),
    );

    final lines = _lines(text);
    expect(lines.first, startsWith('ask:'));
    expect(lines.first, contains('Features'));
    final starter = lines.indexWhere((line) => line.contains('Starter'));
    final library = lines.indexWhere((line) => line.contains('Library'));
    final help = lines.indexWhere(
      (line) => line.startsWith('hint:') && line.contains('Ctrl+T'),
    );
    expect(starter, greaterThan(0));
    expect(library, greaterThan(starter));
    expect(help, greaterThan(library));
    expect(
      lines.where((line) => line.startsWith('result:')),
      isNotEmpty,
      reason: 'the reported outcome keeps its typed diagnostic label',
    );
  });

  test(
    'Colon text input renders the authored light palette and typed labels',
    () async {
      final output = StringBuffer();
      final theme = ColonInternalPresentation(
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
            ColonPaletteDefaults.lightRgb[ColonPaletteRole.foreground]!,
          ),
        ),
      );
      expect(
        text,
        isNot(
          contains(
            _foreground(
              ColonPaletteDefaults.darkRgb[ColonPaletteRole.foreground]!,
            ),
          ),
        ),
      );
      final lines = _lines(text);
      expect(lines.first, startsWith('ask:'));
      expect(lines.first, contains('Project name'));
      expect(
        lines.where((line) => line.startsWith('hint:')),
        isNotEmpty,
        reason: 'the compact hint keeps the explicit prefix',
      );
      expect(
        text,
        contains('  :: '),
        reason: 'the editable row keeps the diagnostic body marker',
      );
    },
  );
}
