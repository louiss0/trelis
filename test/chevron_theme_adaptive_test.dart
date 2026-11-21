import 'dart:async';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/chevron_theme_internal.dart';
import 'package:trelis/src/testing/compat_api.dart';

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

ColorTheme _palette({
  required ChevronRgb foreground,
  required ChevronRgb border,
  required ChevronRgb accent,
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

Future<String> _renderSelect({
  required BackgroundPreference background,
  ColorPreferences? preferences,
  ComponentColors component = const ComponentColors(),
  OutputProfile? profile,
  Map<String, String?> environment = const {},
  ColorDetectionFacts? colorFacts,
}) async {
  final output = StringBuffer();
  final theme = ChevronInternalPresentation(
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

  for (final variant in BackgroundPreference.values.where(
    (value) => value != BackgroundPreference.automatic,
  )) {
    final light = variant == BackgroundPreference.light;
    final expectedRgb = light
        ? ChevronPaletteDefaults.lightRgb
        : ChevronPaletteDefaults.darkRgb;

    test('$variant applies every Chevron palette layer in order', () async {
      final expectedDefault = _foreground(
        expectedRgb[ChevronPaletteRole.foreground]!,
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
    'output capability and NO_COLOR degrade real Chevron rendering',
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
            ChevronPaletteDefaults.darkRgb[ChevronPaletteRole.foreground]!,
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
            ChevronPaletteDefaults.lightRgb[ChevronPaletteRole.foreground]!,
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
            ChevronPaletteDefaults.lightRgb[ChevronPaletteRole.foreground]!,
          ),
        ),
      );
    },
  );

  test('Chevron defaults never paint the terminal surface', () async {
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
          ChevronPaletteDefaults.lightRgb[ChevronPaletteRole.foreground]!,
        ),
      ),
    );
    expect(text, isNot(_foreground(_componentPaletteFg)));
    expect(text, isNot(_foreground((red: 117, green: 118, blue: 119))));
  });

  Future<String> renderMultiSelect(int columns) async {
    final output = StringBuffer();
    final theme = ChevronInternalPresentation(
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
    'ASCII no-colour Chevron keeps independent markers and a hint',
    () async {
      final text = await renderMultiSelect(40);
      final lines = _lines(text);

      expect(text, isNot(contains('\x1b[38;')));
      expect(text, isNot(contains('\x1b[48;')));
      expect(lines.first, startsWith('> Features'));
      expect(text, isNot(contains('\u276f')));
      expect(text, isNot(contains('\u21b3')));

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

      final hint = lines.indexWhere((line) => line.contains('Space toggles'));
      expect(hint, greaterThan(lines.indexOf(defaulted.single)));
      expect(lines[hint], startsWith('  -> '));
      final hintText = lines.skip(hint).join(' ');
      expect(hintText, contains('Ctrl+T'));
      expect(hintText.replaceAll(RegExp(r'\s'), ''), contains('Entersubmits'));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(40), reason: line);
      }
    },
  );

  test(
    'ASCII no-colour validation stays readable beside the compact hint',
    () async {
      final output = StringBuffer();
      final theme = ChevronInternalPresentation(
        io: TerminalEnvironment.scripted(
          input: Stream.value('ab\rc\r'),
          output: output,
          profile: _profile(ascii: true, depth: ColorDepth.none),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(background: BackgroundPreference.dark),
      );

      final result = await theme.textInput(
        'Project name',
        validate: (value) => value == 'abc' ? null : 'Enter abc',
      );

      expect((result as Accepted<String>).value, 'abc');
      final text = output.toString();
      expect(text, isNot(contains('\x1b[38;')));
      expect(text, isNot(contains('\x1b[48;')));
      expect(text, contains('Enter abc'));
      final lines = _lines(text);
      expect(lines.first, startsWith('> Project name'));
      final hintStart = lines.indexWhere((line) => line.contains('-> '));
      expect(hintStart, greaterThan(0));
      expect(
        lines.skip(hintStart).join('').replaceAll(RegExp(r'\s'), ''),
        contains('Ctrl+T'),
      );
    },
  );

  test('narrow ASCII Chevron keeps essentials without a frame', () async {
    final text = await renderMultiSelect(10);
    final lines = _lines(text);

    expect(text, isNot(contains('+===')));
    expect(text, isNot(contains('\u2550')));
    final joined = lines.join('').replaceAll(RegExp(r'\s'), '');
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
    expect(text, isNot(contains('\x1b[2K')));
  });

  test('the pre-cutover Chevron factory keeps its public palette', () async {
    final output = StringBuffer();
    final result = await ChevronTheme.textInput('Name').prompt(
      source: ScriptedInput(
        Stream.value('Ada\r'),
        output,
        outputProfile: _profile(),
      ),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), isNot(contains('\x1b[38;')));
    expect(output.toString(), contains('\u276f'));

    final explicit = StringBuffer();
    await ChevronTheme.textInput('Name', colors: ColorThemes.signal).prompt(
      source: ScriptedInput(
        Stream.value('Ada\r'),
        explicit,
        outputProfile: _profile(),
      ),
      mode: PromptMode.rich,
    );
    expect(explicit.toString(), contains('\x1b[38;2;230;232;244;'));
    expect(explicit.toString(), contains('\u276f'));
  });
}
