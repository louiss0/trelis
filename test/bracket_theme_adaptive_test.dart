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

const _appPaletteFg = (red: 11, green: 22, blue: 33);
const _componentPaletteFg = (red: 44, green: 55, blue: 66);
const _appAccent = (red: 77, green: 88, blue: 99);
const _appLightAccent = (red: 101, green: 102, blue: 103);
const _appDarkAccent = (red: 104, green: 105, blue: 106);
const _componentAccent = (red: 111, green: 112, blue: 113);
const _componentLightAccent = (red: 114, green: 115, blue: 116);
const _componentDarkAccent = (red: 117, green: 118, blue: 119);

ColorTheme _palette({
  required BracketRgb foreground,
  required BracketRgb border,
  required BracketRgb accent,
}) => ColorTheme(
  foreground: TerminalColor.rgb(
    foreground.red,
    foreground.green,
    foreground.blue,
  ),
  background: const TerminalColor.terminalDefault(),
  muted: TerminalColor.rgb(150, 150, 150),
  accent: TerminalColor.rgb(accent.red, accent.green, accent.blue),
  selectionForeground: TerminalColor.rgb(255, 255, 255),
  selectionBackground: TerminalColor.rgb(50, 50, 50),
  success: TerminalColor.rgb(20, 150, 20),
  warning: TerminalColor.rgb(150, 120, 20),
  error: TerminalColor.rgb(150, 20, 20),
  border: TerminalColor.rgb(border.red, border.green, border.blue),
);

final ColorTheme _appPalette = _palette(
  foreground: _appPaletteFg,
  border: (red: 12, green: 23, blue: 34),
  accent: _appAccent,
);
final ColorTheme _componentPalette = _palette(
  foreground: _componentPaletteFg,
  border: (red: 45, green: 56, blue: 67),
  accent: _componentAccent,
);

Future<String> _renderSelect({
  required BackgroundPreference background,
  ColorPreferences? preferences,
  ComponentColors component = const ComponentColors(),
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  ColorDetectionFacts? colorFacts,
}) async {
  final output = StringBuffer();
  final theme = _theme(
    output,
    background: background,
    input: Stream.value('\r'),
    profile: profile,
    colors: preferences ?? ColorPreferences(background: background),
    environment: environment,
    colorFacts: colorFacts,
  );
  await theme.select<String>('Features', [
    Choice('starter', 'Starter'),
    Choice('library', 'Library'),
  ], colors: component);
  return output.toString();
}

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

  for (final variant in [
    (name: 'light', value: BackgroundPreference.light),
    (name: 'dark', value: BackgroundPreference.dark),
  ]) {
    test(
      '${variant.name} applies every Bracket palette layer in order',
      () async {
        final light = variant.value == BackgroundPreference.light;
        final expectedRgb = light
            ? BracketPaletteDefaults.lightRgb
            : BracketPaletteDefaults.darkRgb;
        final defaultForeground = _foreground(
          expectedRgb[BracketPaletteRole.foreground]!,
        );
        final appForeground = _foreground(_appPaletteFg);
        final componentForeground = _foreground(_componentPaletteFg);
        final appAccent = _foreground(_appAccent);
        final appVariantAccent = _foreground(
          light ? _appLightAccent : _appDarkAccent,
        );
        final componentAccent = _foreground(_componentAccent);
        final componentVariantAccent = _foreground(
          light ? _componentLightAccent : _componentDarkAccent,
        );

        var text = await _renderSelect(background: variant.value);
        expect(text, contains(defaultForeground));
        expect(text, isNot(contains(appForeground)));

        text = await _renderSelect(
          background: variant.value,
          preferences: ColorPreferences(
            background: variant.value,
            colors: ComponentColors.palette(_appPalette),
          ),
        );
        expect(text, contains(appForeground));
        expect(text, isNot(contains(defaultForeground)));

        text = await _renderSelect(
          background: variant.value,
          preferences: ColorPreferences(
            background: variant.value,
            colors: ComponentColors(
              palette: _appPalette,
              roles: ColorRoleOverrides(accent: TerminalColor.rgb(77, 88, 99)),
            ),
          ),
        );
        expect(text, contains(appAccent));

        text = await _renderSelect(
          background: variant.value,
          preferences: ColorPreferences(
            background: variant.value,
            colors: ComponentColors(
              palette: _appPalette,
              lightRoles: ColorRoleOverrides(
                accent: TerminalColor.rgb(101, 102, 103),
              ),
              darkRoles: ColorRoleOverrides(
                accent: TerminalColor.rgb(104, 105, 106),
              ),
            ),
          ),
        );
        expect(text, contains(appVariantAccent));
        expect(text, isNot(contains(appAccent)));

        text = await _renderSelect(
          background: variant.value,
          preferences: ColorPreferences(
            background: variant.value,
            colors: ComponentColors(
              palette: _appPalette,
              roles: ColorRoleOverrides(accent: TerminalColor.rgb(77, 88, 99)),
            ),
          ),
          component: ComponentColors.palette(_componentPalette),
        );
        expect(text, contains(componentForeground));
        expect(text, isNot(contains(appForeground)));
        expect(text, isNot(contains(appAccent)));

        text = await _renderSelect(
          background: variant.value,
          preferences: ColorPreferences(
            background: variant.value,
            colors: ComponentColors.palette(_appPalette),
          ),
          component: ComponentColors(
            palette: _componentPalette,
            lightRoles: ColorRoleOverrides(
              accent: TerminalColor.rgb(114, 115, 116),
            ),
            darkRoles: ColorRoleOverrides(
              accent: TerminalColor.rgb(117, 118, 119),
            ),
          ),
        );
        expect(text, contains(componentForeground));
        expect(text, contains(componentVariantAccent));
        expect(text, isNot(contains(componentAccent)));
        expect(text, isNot(contains(appAccent)));
      },
    );
  }

  test('explicit terminal default wins at app and component scope', () async {
    var text = await _renderSelect(
      background: BackgroundPreference.dark,
      preferences: const ColorPreferences(
        background: BackgroundPreference.dark,
        colors: ComponentColors.palette(ColorThemes.terminalDefault),
      ),
    );
    expect(text, isNot(contains('\x1b[38;')));
    expect(text, isNot(contains('\x1b[48;')));
    expect(text, contains('Ctrl+T'));

    text = await _renderSelect(
      background: BackgroundPreference.dark,
      preferences: ColorPreferences(
        background: BackgroundPreference.dark,
        colors: ComponentColors.palette(_appPalette),
      ),
      component: ComponentColors.palette(ColorThemes.terminalDefault),
    );
    expect(text, isNot(contains('\x1b[38;')));
    expect(text, isNot(contains(_foreground(_appPaletteFg))));
  });

  test(
    'output capability and NO_COLOR degrade real Bracket rendering',
    () async {
      final indexed = await _renderSelect(
        background: BackgroundPreference.light,
        profile: _profile(depth: ColorDepth.indexed256),
      );
      expect(indexed, contains('\x1b[38;5;'));
      expect(indexed, isNot(contains('\x1b[38;2;')));

      final plain = await _renderSelect(
        background: BackgroundPreference.light,
        profile: _profile(depth: ColorDepth.none),
      );
      expect(plain, isNot(contains('\x1b[38;')));
      expect(plain, contains('Ctrl+T'));

      final restricted = await _renderSelect(
        background: BackgroundPreference.light,
        environment: const {'NO_COLOR': '1'},
        preferences: ColorPreferences(
          background: BackgroundPreference.light,
          colors: ComponentColors.palette(_appPalette),
        ),
        component: ComponentColors.palette(_componentPalette),
      );
      expect(restricted, isNot(contains('\x1b[38;')));
      expect(restricted, isNot(contains('\x1b[48;')));
      expect(restricted, contains('Ctrl+T'));
    },
  );

  test(
    'unknown background falls back to dark and explicit choice wins',
    () async {
      final fallback = await _renderSelect(
        background: BackgroundPreference.automatic,
        preferences: const ColorPreferences(
          background: BackgroundPreference.automatic,
          allowBackgroundQuery: false,
        ),
      );
      expect(
        fallback,
        contains(
          _foreground(
            BracketPaletteDefaults.darkRgb[BracketPaletteRole.foreground]!,
          ),
        ),
      );

      final explicit = await _renderSelect(
        background: BackgroundPreference.light,
        colorFacts: ColorDetectionFacts(
          outputProfile: _profile(),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
      );
      expect(
        explicit,
        contains(
          _foreground(
            BracketPaletteDefaults.lightRgb[BracketPaletteRole.foreground]!,
          ),
        ),
      );

      final queried = await _renderSelect(
        background: BackgroundPreference.automatic,
        preferences: const ColorPreferences(
          background: BackgroundPreference.automatic,
          allowBackgroundQuery: false,
        ),
        colorFacts: ColorDetectionFacts(
          outputProfile: _profile(),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.light,
        ),
      );
      expect(
        queried,
        contains(
          _foreground(
            BracketPaletteDefaults.lightRgb[BracketPaletteRole.foreground]!,
          ),
        ),
      );
    },
  );

  test('Bracket defaults never paint the terminal surface', () async {
    for (final background in [
      BackgroundPreference.light,
      BackgroundPreference.dark,
    ]) {
      final text = await _renderSelect(background: background);
      expect(text, contains(';49m'));
      expect(text, isNot(contains('48;2;')));
      expect(text, isNot(contains('48;5;')));
      expect(text, isNot(contains('\x1b[?1049h')));
    }
  });

  test('component overrides cannot change the resolved background', () async {
    final text = await _renderSelect(
      background: BackgroundPreference.light,
      component: ComponentColors(
        darkPalette: _componentPalette,
        darkRoles: ColorRoleOverrides(accent: TerminalColor.rgb(117, 118, 119)),
      ),
    );
    expect(
      text,
      contains(
        _foreground(
          BracketPaletteDefaults.lightRgb[BracketPaletteRole.foreground]!,
        ),
      ),
    );
    expect(text, isNot(contains(_foreground(_componentPaletteFg))));
    expect(
      text,
      isNot(contains(_foreground((red: 117, green: 118, blue: 119)))),
    );
  });
}
