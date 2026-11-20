import 'dart:async';
import 'dart:math' as math;

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

ColorTheme _palette({
  required DoubleRgb foreground,
  required DoubleRgb border,
  required DoubleRgb accent,
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

const _appPaletteFg = (red: 11, green: 22, blue: 33);
const _componentPaletteFg = (red: 44, green: 55, blue: 66);
const _appAccent = (red: 77, green: 88, blue: 99);
const _appLightAccent = (red: 101, green: 102, blue: 103);
const _appDarkAccent = (red: 104, green: 105, blue: 106);
const _componentAccent = (red: 111, green: 112, blue: 113);
const _componentLightAccent = (red: 114, green: 115, blue: 116);
const _componentDarkAccent = (red: 117, green: 118, blue: 119);

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

double _relativeLuminance(DoubleRgb rgb) {
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

double _contrast(DoubleRgb first, DoubleRgb second) {
  final a = _relativeLuminance(first);
  final b = _relativeLuminance(second);
  final high = a > b ? a : b;
  final low = a < b ? a : b;
  return (high + 0.05) / (low + 0.05);
}

Future<String> _renderSelect({
  required BackgroundPreference background,
  ColorPreferences? preferences,
  ComponentColors component = const ComponentColors(),
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  ColorDetectionFacts? colorFacts,
}) async {
  final output = StringBuffer();
  final theme = DoubleInternalPresentation(
    io: TerminalEnvironment.scripted(
      input: Stream.value('\r'),
      output: output,
      profile: profile ?? _profile(),
      environment: environment,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.rich),
    colors: preferences ?? ColorPreferences(background: background),
    colorFacts: colorFacts,
  );
  await theme.select<String>('Features', [
    Choice('starter', 'Starter'),
    Choice('library', 'Library'),
  ], colors: component);
  return output.toString();
}

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

  for (final variant in BackgroundPreference.values.where(
    (value) => value != BackgroundPreference.automatic,
  )) {
    final light = variant == BackgroundPreference.light;
    final expectedRgb = light
        ? DoublePaletteDefaults.lightRgb
        : DoublePaletteDefaults.darkRgb;

    test('$variant applies every Double palette layer in order', () async {
      final expectedDefault = _foreground(
        expectedRgb[DoublePaletteRole.foreground]!,
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

      var text = await _renderSelect(background: variant);
      expect(text, contains(expectedDefault));
      expect(text, isNot(appForeground));

      text = await _renderSelect(
        background: variant,
        preferences: ColorPreferences(
          background: variant,
          colors: ComponentColors.palette(_appPalette),
        ),
      );
      expect(text, contains(appForeground));
      expect(text, isNot(expectedDefault));

      text = await _renderSelect(
        background: variant,
        preferences: ColorPreferences(
          background: variant,
          colors: ComponentColors(
            palette: _appPalette,
            roles: ColorRoleOverrides(accent: TerminalColor.rgb(77, 88, 99)),
          ),
        ),
      );
      expect(text, contains(appAccent));

      text = await _renderSelect(
        background: variant,
        preferences: ColorPreferences(
          background: variant,
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
      expect(text, isNot(appAccent));

      text = await _renderSelect(
        background: variant,
        preferences: ColorPreferences(
          background: variant,
          colors: ComponentColors(
            palette: _appPalette,
            roles: ColorRoleOverrides(accent: TerminalColor.rgb(77, 88, 99)),
          ),
        ),
        component: ComponentColors.palette(_componentPalette),
      );
      expect(text, contains(componentForeground));
      expect(text, isNot(appForeground));
      expect(text, isNot(appAccent));

      text = await _renderSelect(
        background: variant,
        preferences: ColorPreferences(
          background: variant,
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
      expect(text, isNot(componentAccent));
      expect(text, isNot(appAccent));
    });
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
    expect(text, contains('Up/Down navigate'));

    text = await _renderSelect(
      background: BackgroundPreference.dark,
      preferences: ColorPreferences(
        background: BackgroundPreference.dark,
        colors: ComponentColors.palette(_appPalette),
      ),
      component: ComponentColors.palette(ColorThemes.terminalDefault),
    );
    expect(text, isNot(contains('\x1b[38;')));
    expect(text, isNot(_foreground(_appPaletteFg)));
  });

  test(
    'output capability and NO_COLOR degrade real Double rendering',
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
      expect(plain, contains('Up/Down navigate'));

      final restricted = await _renderSelect(
        background: BackgroundPreference.light,
        profile: _profile(),
        environment: const {'NO_COLOR': '1'},
        preferences: ColorPreferences(
          background: BackgroundPreference.light,
          colors: ComponentColors.palette(_appPalette),
        ),
        component: ComponentColors.palette(_componentPalette),
      );
      expect(restricted, isNot(contains('\x1b[38;')));
      expect(restricted, isNot(contains('\x1b[48;')));
      expect(restricted, contains('Up/Down navigate'));
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
            DoublePaletteDefaults.darkRgb[DoublePaletteRole.foreground]!,
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
            DoublePaletteDefaults.lightRgb[DoublePaletteRole.foreground]!,
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
            DoublePaletteDefaults.lightRgb[DoublePaletteRole.foreground]!,
          ),
        ),
      );
    },
  );

  test('Double defaults never paint the terminal surface', () async {
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

  Future<String> renderMultiSelect(int columns) async {
    final output = StringBuffer();
    final theme = DoubleInternalPresentation(
      io: TerminalEnvironment.scripted(
        input: Stream.value('\r'),
        output: output,
        profile: _profile(
          ascii: true,
          depth: ColorDepth.none,
          columns: columns,
        ),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(background: BackgroundPreference.dark),
    );
    await theme.multiSelect<String>(
      'Features',
      [
        Choice('starter', 'Starter'),
        Choice('library', 'Library'),
        Choice('locked', 'Locked', disabledReason: 'locked by policy'),
      ],
      defaultValues: const ['library'],
    );
    return output.toString();
  }

  test(
    'ASCII no-colour Double keeps independent markers and contained rows',
    () async {
      final text = await renderMultiSelect(40);
      final lines = _lines(text);

      expect(text, isNot(contains('\x1b[38;')));
      expect(text, isNot(contains('\x1b[48;')));
      expect(lines.first, startsWith('+ Features'));
      expect(lines.first, endsWith('=+'));
      expect(text, contains('+==='));

      final focused = lines
          .where((line) => line.contains('[focused]'))
          .toList();
      final defaulted = lines
          .where((line) => line.contains('[default]'))
          .toList();
      expect(focused, hasLength(1));
      expect(defaulted, hasLength(1));
      expect(focused.single, contains('[unchecked]'));
      expect(focused.single, isNot(contains('[default]')));
      expect(defaulted.single, contains('[checked]'));
      expect(defaulted.single, isNot(contains('[focused]')));
      expect(text, contains('[unavailable: locked by policy]'));

      final bottom = lines.lastIndexWhere(
        (line) => line.startsWith('+===') && line.endsWith('+'),
      );
      expect(bottom, greaterThan(0));
      final afterFrame = lines.skip(bottom + 1).join(' ');
      expect(afterFrame, contains('Space toggles'));
      expect(afterFrame, contains('Ctrl+T'));
      expect(
        afterFrame.replaceAll(RegExp(r'\s'), ''),
        contains('Entersubmits'),
      );
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(40), reason: line);
      }
    },
  );

  test('narrow ASCII Double keeps content without a partial frame', () async {
    final text = await renderMultiSelect(10);
    final lines = _lines(text);

    expect(text, isNot(contains('+===')));
    expect(text, contains('|| '));
    for (final line in lines) {
      expect(line, startsWith('|| '), reason: line);
    }
    final joined = lines
        .join('')
        .replaceAll('||', '')
        .replaceAll(RegExp(r'\s'), '');
    for (final essential in [
      'Features',
      'Starter',
      'Library',
      '[unchecked]',
      '[checked]',
      '[focused]',
      '[default]',
      'Ctrl+T',
    ]) {
      expect(joined, contains(essential), reason: essential);
    }
  });

  test('authored normal-text pairs meet the reference contrast target', () {
    for (final reference in [
      (
        name: 'Atelier Sepia light',
        background: DoublePaletteDefaults.lightReferenceBackground,
        roles: DoublePaletteDefaults.lightRgb,
      ),
      (
        name: 'warm ink dark',
        background: DoublePaletteDefaults.darkReferenceBackground,
        roles: DoublePaletteDefaults.darkRgb,
      ),
    ]) {
      for (final role in [
        DoublePaletteRole.foreground,
        DoublePaletteRole.muted,
        DoublePaletteRole.accent,
        DoublePaletteRole.success,
        DoublePaletteRole.warning,
        DoublePaletteRole.error,
        DoublePaletteRole.border,
      ]) {
        final ratio = _contrast(reference.roles[role]!, reference.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$role against ${reference.name}: $ratio',
        );
      }
      final selectionRatio = _contrast(
        reference.roles[DoublePaletteRole.selectionForeground]!,
        reference.roles[DoublePaletteRole.selectionBackground]!,
      );
      expect(
        selectionRatio,
        greaterThanOrEqualTo(4.5),
        reason: 'selection pair against ${reference.name}',
      );
    }
  });

  test('the pre-cutover Double factory keeps its public palette', () async {
    final output = StringBuffer();
    final result = await DoubleTheme.textInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('Ada\r'),
        output,
        outputProfile: _profile(),
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), isNot(contains('\x1b[38;')));
    expect(output.toString(), contains('╔'));

    final explicit = StringBuffer();
    await DoubleTheme.textInput('Name', colors: ColorThemes.signal).prompt(
      source: ScriptedInput(
        Stream.value('Ada\r'),
        explicit,
        outputProfile: _profile(),
      ),
      mode: PromptMode.rich,
    );
    expect(explicit.toString(), contains('\x1b[38;2;230;232;244;'));
    expect(explicit.toString(), contains('╔'));
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
          DoublePaletteDefaults.lightRgb[DoublePaletteRole.foreground]!,
        ),
      ),
    );
    expect(text, isNot(_foreground(_componentPaletteFg)));
    expect(text, isNot(_foreground((red: 117, green: 118, blue: 119))));
  });
}
