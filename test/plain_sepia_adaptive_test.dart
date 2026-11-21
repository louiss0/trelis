import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/themes/plain_sepia_palettes.dart';
import 'package:trelis/trelis.dart';

/// Reads a request back through the public SGR rendering, so the test does not
/// depend on the private colour subclasses.
List<int> _rgb(TerminalColor color) => terminalSgr(
  color,
  background: false,
  depth: ColorDepth.rgb,
).split(';').skip(2).map(int.parse).toList();

double _contrast(List<int> foreground, List<int> background) {
  double luminance(List<int> rgb) {
    final channels = rgb.map((value) {
      final channel = value / 255;
      return channel <= 0.03928
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    });
    return 0.2126 * channels.elementAt(0) +
        0.7152 * channels.elementAt(1) +
        0.0722 * channels.elementAt(2);
  }

  final lighter = luminance(foreground);
  final darker = luminance(background);
  return lighter > darker
      ? (lighter + 0.05) / (darker + 0.05)
      : (darker + 0.05) / (lighter + 0.05);
}

void main() {
  group('Plain adaptive sepia defaults', () {
    test('light and dark defaults are distinct warm-ink palettes', () {
      final light = PlainSepiaPalettes.light;
      final dark = PlainSepiaPalettes.dark;

      expect(light.foreground, isNot(dark.foreground));
      expect(light.accent, isNot(dark.accent));
      expect(isTerminalDefault(light.background), isTrue);
      expect(isTerminalDefault(dark.background), isTrue);

      final lightAccent = _rgb(light.accent);
      final darkAccent = _rgb(dark.accent);
      expect(lightAccent[0], greaterThan(lightAccent[1]));
      expect(lightAccent[1], greaterThan(lightAccent[2]));
      expect(darkAccent[0], greaterThan(darkAccent[1]));
      expect(darkAccent[1], greaterThan(darkAccent[2]));
    });

    test(
      'each authored normal-text pair meets the reference contrast target',
      () {
        final variants = [
          (PlainSepiaPalettes.light, plainLightReferenceRgb),
          (PlainSepiaPalettes.dark, plainDarkReferenceRgb),
        ];
        for (final (palette, reference) in variants) {
          final roles = <String, TerminalColor>{
            'foreground': palette.foreground,
            'muted': palette.muted,
            'accent': palette.accent,
            'success': palette.success,
            'warning': palette.warning,
            'error': palette.error,
            'border': palette.border,
          };
          for (final MapEntry(:key, :value) in roles.entries) {
            expect(
              _contrast(_rgb(value), [
                reference.$1,
                reference.$2,
                reference.$3,
              ]),
              greaterThanOrEqualTo(4.5),
              reason: '$key against documented reference $reference',
            );
          }
          expect(
            _contrast(
              _rgb(palette.selectionForeground),
              _rgb(palette.selectionBackground),
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'localized selection highlight $reference',
          );
        }
      },
    );
  });

  group('Plain adaptive colour resolution', () {
    test('explicit choice wins and unknown background falls back to dark', () {
      final explicit = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
      );
      final queried = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.light,
        ),
      );
      final passive = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          passiveBackground: BackgroundObservation.light,
        ),
      );
      final unknown = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          queriedBackground: BackgroundObservation.malformed,
        ),
      );

      expect(explicit.background, BackgroundVariant.light);
      expect(queried.background, BackgroundVariant.light);
      expect(passive.background, BackgroundVariant.light);
      expect(unknown.background, BackgroundVariant.dark);
      expect(explicit.palette.foreground, PlainSepiaPalettes.light.foreground);
      expect(queried.palette.foreground, PlainSepiaPalettes.light.foreground);
      expect(unknown.palette.foreground, PlainSepiaPalettes.dark.foreground);
      expect(explicit.shouldQueryBackground, isFalse);
      expect(queried.shouldQueryBackground, isFalse);
      expect(passive.shouldQueryBackground, isTrue);
    });

    test(
      'app roles layer over defaults and component replacement discards them',
      () {
        final appPalette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(1, 2, 3),
        );
        final appAccent = TerminalColor.rgb(4, 5, 6);
        final appDarkAccent = TerminalColor.rgb(7, 8, 9);
        final componentPalette = ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(10, 11, 12),
        );
        final componentAccent = TerminalColor.rgb(13, 14, 15);
        final preferences = ColorPreferences(
          colors: ComponentColors(
            palette: appPalette,
            roles: ColorRoleOverrides(accent: appAccent),
            darkRoles: ColorRoleOverrides(accent: appDarkAccent),
          ),
        );
        final facts = const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
        );

        final appOnly = resolvePlainColors(
          facts: facts,
          preferences: preferences,
        );
        final withComponent = resolvePlainColors(
          facts: facts,
          preferences: preferences,
          component: ComponentColors(
            palette: componentPalette,
            roles: ColorRoleOverrides(accent: componentAccent),
          ),
        );

        expect(appOnly.palette.foreground, appPalette.foreground);
        expect(appOnly.palette.accent, appDarkAccent);
        expect(withComponent.palette.foreground, componentPalette.foreground);
        expect(withComponent.palette.accent, componentAccent);
        expect(
          withComponent.palette.accent,
          isNot(anyOf(appAccent, appDarkAccent)),
        );
      },
    );

    test('variant roles win over shared roles in both scopes', () {
      final shared = TerminalColor.rgb(20, 21, 22);
      final lightAccent = TerminalColor.rgb(23, 24, 25);
      final darkAccent = TerminalColor.rgb(26, 27, 28);
      final resolved = resolvePlainColors(
        facts: const ColorDetectionFacts(
          outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
        ),
        preferences: ColorPreferences(
          colors: ComponentColors(
            roles: ColorRoleOverrides(accent: shared),
            lightRoles: ColorRoleOverrides(accent: lightAccent),
            darkRoles: ColorRoleOverrides(accent: darkAccent),
          ),
        ),
        component: ComponentColors(
          roles: ColorRoleOverrides(border: shared),
          lightRoles: ColorRoleOverrides(border: lightAccent),
          darkRoles: ColorRoleOverrides(border: darkAccent),
        ),
      );

      expect(resolved.palette.accent, darkAccent);
      expect(resolved.palette.border, darkAccent);
    });

    test('terminalDefault is an explicit palette at either scope', () {
      final facts = const ColorDetectionFacts(
        outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
      );
      final atApp = resolvePlainColors(
        facts: facts,
        preferences: const ColorPreferences(
          colors: ComponentColors.palette(ColorThemes.terminalDefault),
        ),
      );
      final atComponent = resolvePlainColors(
        facts: facts,
        component: const ComponentColors.palette(ColorThemes.terminalDefault),
      );

      expect(isTerminalDefault(atApp.palette.foreground), isTrue);
      expect(isTerminalDefault(atComponent.palette.foreground), isTrue);
    });

    test(
      'NO_COLOR and output depth restrict colour requests at the boundary',
      () {
        final explicit = ComponentColors.palette(
          ColorThemes.terminalDefault.copyWith(
            foreground: TerminalColor.rgb(31, 32, 33),
          ),
        );
        final restricted = resolvePlainColors(
          facts: const ColorDetectionFacts(
            noColor: '1',
            outputProfile: OutputProfile(colorDepth: ColorDepth.rgb),
          ),
          component: explicit,
        );
        final degraded = resolvePlainColors(
          facts: const ColorDetectionFacts(
            outputProfile: OutputProfile(colorDepth: ColorDepth.indexed256),
          ),
        );
        final unknownDepth = resolvePlainColors();

        expect(restricted.outputProfile.colorDepth, ColorDepth.none);
        expect(restricted.shouldQueryBackground, isFalse);
        expect(degraded.outputProfile.colorDepth, ColorDepth.indexed256);
        expect(unknownDepth.outputProfile.colorDepth, ColorDepth.none);
        expect(unknownDepth.shouldQueryBackground, isFalse);
      },
    );
  });
}
