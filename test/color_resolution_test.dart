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
    ColorDetectionFacts facts = const ColorDetectionFacts(),
  }) => resolveColors(
    facts: facts,
    lightDefault: lightDefault,
    darkDefault: darkDefault,
    preferences: preferences,
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
}
