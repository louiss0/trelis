import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  final lightDefault = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(240, 238, 230),
  );
  final darkDefault = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(30, 32, 38),
  );

  ResolvedColors resolveTestColors({
    ColorPreferences preferences = const ColorPreferences(),
    ComponentColors? component,
    ColorDetectionFacts facts = const ColorDetectionFacts(),
  }) => resolveColors(
    facts: facts,
    lightDefault: lightDefault,
    darkDefault: darkDefault,
    preferences: preferences,
    component: component,
  );

  group('colour background resolution from injected facts', () {
    test('explicit background wins over query and passive hint', () {
      final result = resolveTestColors(
        preferences: const ColorPreferences(
          background: BackgroundPreference.light,
        ),
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.dark,
          queriedBackground: BackgroundObservation.dark,
        ),
      );

      expect(result.background, BackgroundVariant.light);
      expect(result.palette.foreground, TerminalColor.rgb(240, 238, 230));
    });

    test(
      'valid query wins over passive hint and unknown falls back to dark',
      () {
        final queried = resolveTestColors(
          facts: const ColorDetectionFacts(
            passiveBackground: BackgroundObservation.dark,
            queriedBackground: BackgroundObservation.light,
          ),
        );
        final passive = resolveTestColors(
          facts: const ColorDetectionFacts(
            passiveBackground: BackgroundObservation.light,
          ),
        );
        final unknown = resolveTestColors();

        expect(queried.background, BackgroundVariant.light);
        expect(queried.palette.foreground, TerminalColor.rgb(240, 238, 230));
        expect(passive.background, BackgroundVariant.light);
        expect(unknown.background, BackgroundVariant.dark);
        expect(unknown.palette.foreground, TerminalColor.rgb(30, 32, 38));
      },
    );

    test(
      'malformed and unavailable observations do not select a background',
      () {
        expect(
          parseBackgroundObservation('light'),
          BackgroundObservation.light,
        );
        expect(parseBackgroundObservation('dark'), BackgroundObservation.dark);
        expect(
          parseBackgroundObservation('purple'),
          BackgroundObservation.malformed,
        );
        expect(
          parseBackgroundObservation(null),
          BackgroundObservation.unavailable,
        );

        final malformedQuery = resolveTestColors(
          facts: const ColorDetectionFacts(
            passiveBackground: BackgroundObservation.light,
            queriedBackground: BackgroundObservation.malformed,
          ),
        );
        final unavailableQuery = resolveTestColors(
          facts: const ColorDetectionFacts(
            queriedBackground: BackgroundObservation.unavailable,
          ),
        );

        expect(malformedQuery.background, BackgroundVariant.light);
        expect(unavailableQuery.background, BackgroundVariant.dark);
      },
    );
  });

  group('colour preference layering', () {
    final appPalette = ColorThemes.terminalDefault.copyWith(
      foreground: TerminalColor.indexed(100),
      muted: TerminalColor.indexed(101),
    );
    final componentPalette = ColorThemes.terminalDefault.copyWith(
      foreground: TerminalColor.indexed(200),
      muted: TerminalColor.indexed(201),
    );

    for (final variant in BackgroundVariant.values) {
      final isLight = variant == BackgroundVariant.light;
      final preferredBackground = isLight
          ? BackgroundPreference.light
          : BackgroundPreference.dark;

      test('app variant roles win app shared roles for $variant', () {
        final result = resolveTestColors(
          preferences: ColorPreferences(
            background: preferredBackground,
            colors: ComponentColors(
              palette: appPalette,
              roles: ColorRoleOverrides(
                accent: TerminalColor.indexed(11),
                warning: TerminalColor.indexed(12),
              ),
              lightRoles: ColorRoleOverrides(
                accent: TerminalColor.indexed(13),
                success: TerminalColor.indexed(14),
              ),
              darkRoles: ColorRoleOverrides(
                accent: TerminalColor.indexed(15),
                success: TerminalColor.indexed(16),
              ),
            ),
          ),
        );

        expect(result.palette.foreground, TerminalColor.indexed(100));
        expect(result.palette.muted, TerminalColor.indexed(101));
        expect(result.palette.accent, TerminalColor.indexed(isLight ? 13 : 15));
        expect(result.palette.warning, TerminalColor.indexed(12));
        expect(
          result.palette.success,
          TerminalColor.indexed(isLight ? 14 : 16),
        );
      });

      test(
        'component roles layer over an inherited app palette for $variant',
        () {
          final result = resolveTestColors(
            preferences: ColorPreferences(
              background: preferredBackground,
              colors: ComponentColors(
                palette: appPalette,
                roles: ColorRoleOverrides(warning: TerminalColor.indexed(12)),
              ),
            ),
            component: ComponentColors(
              roles: ColorRoleOverrides(accent: TerminalColor.indexed(21)),
              lightRoles: ColorRoleOverrides(error: TerminalColor.indexed(22)),
              darkRoles: ColorRoleOverrides(error: TerminalColor.indexed(23)),
            ),
          );

          expect(result.palette.foreground, TerminalColor.indexed(100));
          expect(result.palette.warning, TerminalColor.indexed(12));
          expect(result.palette.accent, TerminalColor.indexed(21));
          expect(
            result.palette.error,
            TerminalColor.indexed(isLight ? 22 : 23),
          );
        },
      );
    }

    test('component replacement discards the whole effective app palette', () {
      final result = resolveTestColors(
        preferences: ColorPreferences(
          background: BackgroundPreference.light,
          colors: ComponentColors(
            palette: appPalette,
            roles: ColorRoleOverrides(
              accent: TerminalColor.indexed(11),
              warning: TerminalColor.indexed(12),
            ),
            lightRoles: ColorRoleOverrides(success: TerminalColor.indexed(14)),
          ),
        ),
        component: ComponentColors(
          palette: componentPalette,
          roles: ColorRoleOverrides(accent: TerminalColor.indexed(21)),
        ),
      );

      expect(result.palette.foreground, TerminalColor.indexed(200));
      expect(result.palette.muted, TerminalColor.indexed(201));
      expect(result.palette.accent, TerminalColor.indexed(21));
      expect(result.palette.warning, appPalette.warning);
      expect(result.palette.success, appPalette.success);
    });

    test('variant replacement applies only to the selected background', () {
      final darkAppPalette = ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.indexed(110),
      );
      final lightComponentPalette = ColorThemes.terminalDefault.copyWith(
        foreground: TerminalColor.indexed(210),
      );
      final preferences = ColorPreferences(
        colors: ComponentColors(
          lightPalette: appPalette,
          darkPalette: darkAppPalette,
        ),
      );
      final component = ComponentColors(
        lightPalette: lightComponentPalette,
        roles: ColorRoleOverrides(accent: TerminalColor.indexed(31)),
      );

      final light = resolveTestColors(
        preferences: preferences,
        component: component,
        facts: const ColorDetectionFacts(
          passiveBackground: BackgroundObservation.light,
        ),
      );
      final dark = resolveTestColors(
        preferences: preferences,
        component: component,
      );

      expect(light.palette.foreground, TerminalColor.indexed(210));
      expect(dark.palette.foreground, TerminalColor.indexed(110));
      expect(light.palette.accent, TerminalColor.indexed(31));
      expect(dark.palette.accent, TerminalColor.indexed(31));
    });

    test(
      'omission inherits defaults and explicit native palettes stay native',
      () {
        final inherited = resolveTestColors();
        expect(inherited.palette.foreground, TerminalColor.rgb(30, 32, 38));

        final appNative = resolveTestColors(
          preferences: const ColorPreferences(
            colors: ComponentColors(palette: ColorThemes.terminalDefault),
          ),
        );
        final componentNative = resolveTestColors(
          component: ComponentColors.palette(ColorThemes.terminalDefault),
        );

        for (final result in [appNative, componentNative]) {
          expect(isTerminalDefault(result.palette.foreground), isTrue);
          expect(isTerminalDefault(result.palette.background), isTrue);
          expect(isTerminalDefault(result.palette.accent), isTrue);
        }
      },
    );
  });
}
