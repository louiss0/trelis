import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/structural_theme_palettes.dart';
import 'package:trelis/src/testing/compat_api.dart';

/// Palette evidence for the Box structural theme.
///
/// Expected role values are independent literals, not values read back from
/// the authored palettes. The resolver is exercised with Box's defaults at
/// both variants so the precedence and output-boundary rules are checked for
/// this theme rather than only for a generic fixture.
void main() {
  final box = StructuralThemePalettes.box;
  final rgbProfile = OutputProfile(colorDepth: ColorDepth.rgb);

  ResolvedColors resolve({
    ColorPreferences preferences = const ColorPreferences(),
    ComponentColors? component,
    ColorDetectionFacts facts = const ColorDetectionFacts(),
  }) => resolveColors(
    facts: facts,
    lightDefault: box.light,
    darkDefault: box.dark,
    preferences: preferences,
    component: component,
  );

  ColorTheme appPalette(BackgroundVariant variant) =>
      ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.indexed(
          variant == BackgroundVariant.light ? 100 : 110,
        ),
        muted: TerminalColor.indexed(101),
      );

  ColorTheme componentPalette() => ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.indexed(200),
    muted: TerminalColor.indexed(201),
    warning: TerminalColor.indexed(202),
  );

  group('Box authored adaptive defaults', () {
    test(
      'light and dark defaults are distinct warm-ink palettes with rust',
      () {
        expect(box.light.foreground, TerminalColor.rgb(51, 41, 31));
        expect(box.light.accent, TerminalColor.rgb(166, 69, 38));
        expect(box.dark.foreground, TerminalColor.rgb(243, 233, 220));
        expect(box.dark.accent, TerminalColor.rgb(232, 135, 90));
        expect(box.light.accent, isNot(box.dark.accent));
        expect(box.light.foreground, isNot(box.dark.foreground));
        for (final palette in [box.light, box.dark]) {
          expect(isTerminalDefault(palette.background), isTrue);
          expect(palette.success, isNot(palette.accent));
          expect(palette.warning, isNot(palette.accent));
          expect(palette.error, isNot(palette.accent));
          expect(palette.selectionForeground, isNot(palette.foreground));
        }
      },
    );

    test('unknown background falls back to dark; explicit choice wins', () {
      final unknown = resolve();
      expect(unknown.background, BackgroundVariant.dark);
      expect(unknown.palette.foreground, box.dark.foreground);

      final light = resolve(
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
      );
      expect(light.background, BackgroundVariant.light);
      expect(light.palette.foreground, box.light.foreground);

      final queried = resolve(
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.light,
        ),
      );
      expect(queried.background, BackgroundVariant.light);
      expect(queried.palette.foreground, box.light.foreground);

      final malformed = resolve(
        facts: const ColorDetectionFacts(
          queriedBackground: BackgroundObservation.malformed,
          passiveBackground: BackgroundObservation.light,
        ),
      );
      expect(malformed.background, BackgroundVariant.light);
    });
  });

  for (final variant in BackgroundVariant.values) {
    final isLight = variant == BackgroundVariant.light;
    final preference = isLight
        ? BackgroundPreference.light
        : BackgroundPreference.dark;
    final authored = isLight ? box.light : box.dark;

    group('Box palette precedence / ${variant.name}', () {
      test('omission uses the authored default', () {
        final result = resolve(
          preferences: ColorPreferences(background: preference),
        );
        expect(result.palette, same(authored));
      });

      test(
        'app replacement and its shared and variant roles layer in order',
        () {
          final result = resolve(
            preferences: ColorPreferences(
              background: preference,
              colors: ComponentColors(
                palette: appPalette(variant),
                roles: ColorRoleOverrides(
                  accent: TerminalColor.indexed(11),
                  warning: TerminalColor.indexed(12),
                ),
                lightRoles: ColorRoleOverrides(
                  success: TerminalColor.indexed(13),
                ),
                darkRoles: ColorRoleOverrides(
                  success: TerminalColor.indexed(14),
                ),
              ),
            ),
          );
          expect(
            result.palette.foreground,
            TerminalColor.indexed(isLight ? 100 : 110),
          );
          expect(result.palette.muted, TerminalColor.indexed(101));
          expect(result.palette.accent, TerminalColor.indexed(11));
          expect(result.palette.warning, TerminalColor.indexed(12));
          expect(
            result.palette.success,
            TerminalColor.indexed(isLight ? 13 : 14),
          );
        },
      );

      test('component roles layer over the effective app palette', () {
        final result = resolve(
          preferences: ColorPreferences(
            background: preference,
            colors: ComponentColors(
              palette: appPalette(variant),
              roles: ColorRoleOverrides(warning: TerminalColor.indexed(12)),
            ),
          ),
          component: ComponentColors(
            roles: ColorRoleOverrides(accent: TerminalColor.indexed(21)),
            lightRoles: ColorRoleOverrides(error: TerminalColor.indexed(22)),
            darkRoles: ColorRoleOverrides(error: TerminalColor.indexed(23)),
          ),
        );
        expect(
          result.palette.foreground,
          TerminalColor.indexed(isLight ? 100 : 110),
        );
        expect(result.palette.warning, TerminalColor.indexed(12));
        expect(result.palette.accent, TerminalColor.indexed(21));
        expect(result.palette.error, TerminalColor.indexed(isLight ? 22 : 23));
      });

      test(
        'component replacement discards the complete app palette and roles',
        () {
          final result = resolve(
            preferences: ColorPreferences(
              background: preference,
              colors: ComponentColors(
                palette: appPalette(variant),
                roles: ColorRoleOverrides(
                  accent: TerminalColor.indexed(11),
                  warning: TerminalColor.indexed(12),
                ),
              ),
            ),
            component: ComponentColors(
              palette: componentPalette(),
              roles: ColorRoleOverrides(accent: TerminalColor.indexed(21)),
            ),
          );
          expect(result.palette.foreground, TerminalColor.indexed(200));
          expect(result.palette.muted, TerminalColor.indexed(201));
          expect(result.palette.accent, TerminalColor.indexed(21));
          expect(result.palette.warning, TerminalColor.indexed(202));
        },
      );

      test('a component override cannot change background or I/O facts', () {
        final baseline = resolve(
          preferences: ColorPreferences(background: preference),
          facts: ColorDetectionFacts(outputProfile: rgbProfile),
        );
        final overridden = resolve(
          preferences: ColorPreferences(background: preference),
          facts: ColorDetectionFacts(outputProfile: rgbProfile),
          component: ComponentColors(
            palette: componentPalette(),
            lightPalette: componentPalette(),
            darkPalette: componentPalette(),
          ),
        );
        expect(overridden.background, baseline.background);
        expect(overridden.outputProfile, same(rgbProfile));
        expect(overridden.shouldQueryBackground, false);
      });
    });
  }

  group('explicit terminal-native palettes and the output boundary', () {
    test('terminalDefault at app scope replaces the Box default', () {
      final result = resolve(
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
          colors: ComponentColors.palette(ColorThemes.terminalDefault),
        ),
      );
      expect(isTerminalDefault(result.palette.foreground), isTrue);
      expect(isTerminalDefault(result.palette.accent), isTrue);
      expect(isTerminalDefault(result.palette.border), isTrue);
    });

    test('terminalDefault at component scope replaces the app palette', () {
      final result = resolve(
        preferences: ColorPreferences(
          colors: ComponentColors.palette(appPalette(BackgroundVariant.dark)),
        ),
        component: ComponentColors.palette(ColorThemes.terminalDefault),
      );
      for (final role in [
        result.palette.foreground,
        result.palette.background,
        result.palette.muted,
        result.palette.accent,
        result.palette.selectionForeground,
        result.palette.selectionBackground,
        result.palette.success,
        result.palette.warning,
        result.palette.error,
        result.palette.border,
      ]) {
        expect(isTerminalDefault(role), isTrue);
      }
    });

    test(
      'non-empty NO_COLOR is a hard final restriction against explicit color',
      () {
        final result = resolve(
          preferences: const ColorPreferences(
            background: BackgroundPreference.light,
            colors: ComponentColors.palette(ColorThemes.terminalDefault),
          ),
          component: ComponentColors(
            palette: ColorThemes.terminalDefault.copyWith(
              foreground: TerminalColor.rgb(200, 10, 20),
              background: TerminalColor.rgb(0, 0, 0),
            ),
          ),
          facts: const ColorDetectionFacts(
            outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
            noColor: '1',
          ),
        );
        expect(result.outputProfile.colorDepth, ColorDepth.none);
        expect(result.shouldQueryBackground, isFalse);
        expect(
          terminalStyledText(
            'ready',
            foreground: result.palette.foreground,
            background: result.palette.background,
            depth: result.outputProfile.colorDepth,
          ),
          'ready',
        );
      },
    );

    test('output depth degrades the rust accent predictably', () {
      String styled(ColorDepth depth) => terminalStyledText(
        'X',
        foreground: box.light.accent,
        background: box.light.background,
        depth: depth,
      );
      expect(styled(ColorDepth.rgb), '\x1b[38;2;166;69;38;49mX\x1b[0m');
      expect(styled(ColorDepth.indexed256), '\x1b[38;5;130;49mX\x1b[0m');
      expect(styled(ColorDepth.ansi16), '\x1b[32;49mX\x1b[0m');
      expect(styled(ColorDepth.none), 'X');
    });
  });

  group('Box authored normal-text contrast references', () {
    for (final entry in {
      'light': (
        palette: box.light,
        background: BoxPaletteReference.lightBackground,
        roles: <String, ({int red, int green, int blue, TerminalColor color})>{
          'foreground': (
            red: 51,
            green: 41,
            blue: 31,
            color: box.light.foreground,
          ),
          'muted': (red: 110, green: 96, blue: 81, color: box.light.muted),
          'accent': (red: 166, green: 69, blue: 38, color: box.light.accent),
          'border': (red: 122, green: 102, blue: 80, color: box.light.border),
          'success': (red: 47, green: 107, blue: 70, color: box.light.success),
          'warning': (red: 138, green: 90, blue: 22, color: box.light.warning),
          'error': (red: 158, green: 47, blue: 43, color: box.light.error),
        },
      ),
      'dark': (
        palette: box.dark,
        background: BoxPaletteReference.darkBackground,
        roles: <String, ({int red, int green, int blue, TerminalColor color})>{
          'foreground': (
            red: 243,
            green: 233,
            blue: 220,
            color: box.dark.foreground,
          ),
          'muted': (red: 187, green: 168, blue: 150, color: box.dark.muted),
          'accent': (red: 232, green: 135, blue: 90, color: box.dark.accent),
          'border': (red: 156, green: 132, blue: 110, color: box.dark.border),
          'success': (red: 155, green: 200, blue: 154, color: box.dark.success),
          'warning': (red: 227, green: 183, blue: 97, color: box.dark.warning),
          'error': (red: 242, green: 148, blue: 134, color: box.dark.error),
        },
      ),
    }.entries) {
      for (final role in entry.value.roles.entries) {
        test(
          '${entry.key} ${role.key} reaches 4.5:1 on the reference surface',
          () {
            expect(
              role.value.color,
              TerminalColor.rgb(
                role.value.red,
                role.value.green,
                role.value.blue,
              ),
            );
            expect(
              contrastRatio(
                (role.value.red, role.value.green, role.value.blue),
                (
                  entry.value.background.red,
                  entry.value.background.green,
                  entry.value.background.blue,
                ),
              ),
              greaterThanOrEqualTo(4.5),
            );
          },
        );
      }
    }

    test(
      'selection foreground reaches 4.5:1 on its rust selection background',
      () {
        expect(
          contrastRatio((255, 253, 247), (166, 69, 38)),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio((30, 27, 25), (232, 135, 90)),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('the reference surface is not a painted palette background', () {
      for (final palette in [box.light, box.dark]) {
        expect(isTerminalDefault(palette.background), isTrue);
      }
    });
  });

  group('no partial public cutover', () {
    test('public Box factories still default to terminal-native colours', () {
      expect(BoxTheme.textInput('Name').colors, ColorThemes.terminalDefault);
      expect(
        BoxTheme.multiSelect<String>('Choice', const []).colors,
        ColorThemes.terminalDefault,
      );
    });

    test(
      'the adaptive defaults are not one of the generated atlas presets',
      () {
        final presets = <ColorTheme>[
          ColorThemes.punch,
          ColorThemes.clay,
          ColorThemes.copper,
          ColorThemes.ember,
        ];
        for (final preset in presets) {
          expect(box.light, isNot(preset));
          expect(box.dark, isNot(preset));
        }
      },
    );

    test(
      'generated theme instances adopt their authored adaptive defaults',
      () {
        final template = File('lib/src/themes/plain_theme.dart')
            .readAsStringSync();
        final generated = File('lib/src/themes/box_theme.dart')
            .readAsStringSync();
        final atlas = File('lib/src/color_theme_palettes.g.dart')
            .readAsStringSync();
        expect(template, contains('extends StructuralTheme'));
        expect(generated, contains('extends StructuralTheme'));
        expect(generated, contains('PromptStructure.box'));
        expect(generated, contains('StructuralThemePalettes.box.defaults'));
        expect(generated, isNot(contains('static TextInput textInput')));
        expect(atlas, contains('static const terminalDefault'));
        expect(atlas, isNot(contains('BoxThemeDefault')));
      },
    );
  });
}

double contrastRatio((int, int, int) foreground, (int, int, int) background) {
  final lighter = _luminance(foreground);
  final darker = _luminance(background);
  final high = lighter > darker ? lighter : darker;
  final low = lighter > darker ? darker : lighter;
  return (high + 0.05) / (low + 0.05);
}

double _luminance((int, int, int) color) {
  double channel(int value) {
    final scaled = value / 255;
    return scaled <= 0.03928
        ? scaled / 12.92
        : math.pow((scaled + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.$1) +
      0.7152 * channel(color.$2) +
      0.0722 * channel(color.$3);
}
