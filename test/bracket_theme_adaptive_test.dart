import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/bracket_theme_internal.dart';
import 'package:trelis/trelis.dart';

double _relativeLuminance(BracketRgb rgb) {
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

double _contrast(BracketRgb first, BracketRgb second) {
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

String _foreground(BracketRgb rgb) =>
    '\x1b[38;2;${rgb.red};${rgb.green};${rgb.blue};49m';

List<String> _lines(String text) => text
    .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
    .replaceAll('\r', '')
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .toList();

BracketInternalPresentation _theme(
  StringBuffer output, {
  required BackgroundPreference background,
  Stream<String>? input,
  OutputProfile? profile,
  ColorPreferences? colors,
  Map<String, String?> environment = const {},
  ColorDetectionFacts? colorFacts,
  PromptMode mode = PromptMode.rich,
}) => BracketInternalPresentation(
  io: TerminalEnvironment.scripted(
    input: input ?? Stream.value('Ada\r'),
    output: output,
    profile: profile ?? _profile(),
    environment: environment,
  ),
  interaction: InteractionPreferences(mode: mode),
  colors: colors ?? ColorPreferences(background: background),
  colorFacts: colorFacts,
);

void main() {
  test('authored normal-text pairs meet the reference contrast target', () {
    for (final reference in [
      (
        name: 'Atelier Sepia light',
        background: BracketPaletteDefaults.lightReferenceBackground,
        roles: BracketPaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: BracketPaletteDefaults.darkReferenceBackground,
        roles: BracketPaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        BracketPaletteRole.foreground,
        BracketPaletteRole.muted,
        BracketPaletteRole.accent,
        BracketPaletteRole.success,
        BracketPaletteRole.warning,
        BracketPaletteRole.error,
        BracketPaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[BracketPaletteRole.selectionForeground]!,
        reference.roles[BracketPaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });

  test('authored defaults keep the terminal surface and a rust accent', () {
    for (final palette in [
      BracketPaletteDefaults.light,
      BracketPaletteDefaults.dark,
    ]) {
      expect(palette.background, const TerminalColor.terminalDefault());
      expect(isTerminalDefault(palette.background), isTrue);
    }
    expect(BracketPaletteDefaults.light.accent, TerminalColor.rgb(166, 69, 38));
    expect(BracketPaletteDefaults.dark.accent, TerminalColor.rgb(232, 135, 90));
    expect(ColorThemes.terminalDefault.foreground, isA<TerminalColor>());
  });

  for (final variant in [
    (name: 'light', value: BackgroundPreference.light),
    (name: 'dark', value: BackgroundPreference.dark),
  ]) {
    test(
      'a real Bracket text input renders the authored ${variant.name} palette',
      () async {
        final output = StringBuffer();
        final expected = variant.value == BackgroundPreference.light
            ? BracketPaletteDefaults.lightRgb
            : BracketPaletteDefaults.darkRgb;
        final other = variant.value == BackgroundPreference.light
            ? BracketPaletteDefaults.darkRgb
            : BracketPaletteDefaults.lightRgb;

        final result = await _theme(
          output,
          background: variant.value,
        ).textInput('Project name');

        expect((result as Accepted<String>).value, 'Ada');
        final text = output.toString();
        expect(
          text,
          contains(_foreground(expected[BracketPaletteRole.foreground]!)),
        );
        expect(
          text,
          isNot(contains(_foreground(other[BracketPaletteRole.foreground]!))),
        );
        final lines = _lines(text);
        expect(lines.first, startsWith('[ '));
        expect(lines.first, endsWith(' ]'));
        expect(lines.first, contains('Project name'));
        expect(lines.any((line) => line.startsWith('  ')), isTrue);
        expect(lines.any((line) => line.contains('» ')), isTrue);
        expect(
          lines.indexWhere((line) => line.contains('Ctrl+T')),
          greaterThan(0),
        );
      },
    );
  }

  test('a real Bracket choice keeps the band above indented answers', () async {
    final output = StringBuffer();
    final result =
        await _theme(
          output,
          background: BackgroundPreference.dark,
          input: Stream.value('\r'),
        ).multiSelect<String>(
          'Features',
          [Choice('starter', 'Starter'), Choice('library', 'Library')],
          defaultValues: const ['library'],
        );

    expect((result as Accepted<List<String>>).value, ['library']);
    final text = output.toString();
    final lines = _lines(text);
    expect(lines.first, startsWith('[ '));
    expect(lines.first, contains('Features'));
    final bandEnd = lines.indexWhere((line) => line.endsWith(' ]'));
    expect(bandEnd, greaterThanOrEqualTo(0));
    final starter = lines.indexWhere((line) => line.contains('Starter'));
    final library = lines.indexWhere((line) => line.contains('Library'));
    final help = lines.indexWhere((line) => line.contains('Ctrl+T'));
    expect(starter, greaterThan(bandEnd));
    expect(library, greaterThan(starter));
    expect(help, greaterThan(library));
    for (final answer in lines.getRange(bandEnd + 1, help)) {
      expect(answer, startsWith('  '), reason: answer);
    }
    expect(
      text,
      contains(
        _foreground(
          BracketPaletteDefaults.darkRgb[BracketPaletteRole.foreground]!,
        ),
      ),
    );
    expect(
      text,
      contains(
        _foreground(BracketPaletteDefaults.darkRgb[BracketPaletteRole.accent]!),
      ),
      reason: 'the focused answer uses the authored rust accent',
    );
  });
}
