import 'package:test/test.dart';
import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/trelis.dart';

final _richOutput = OutputProfile(
  cursor: CapabilitySupport.supported,
  geometry: OutputGeometry.fixed(columns: 80, rows: 24),
);

void main() {
  test('a positive native reader hint enables automatic linear mode', () async {
    final probed = <HintPlatform>[];
    final observations = NativeHintObservations(
      platform: HintPlatform.windows,
      interactive: true,
      localSessionAttested: true,
      readerProbe: (platform) async {
        probed.add(platform);
        return ScreenReaderObservation.positive;
      },
    );

    final facts = await observations.facts(output: _richOutput);
    final resolution = resolveInteraction(
      preferences: const InteractionPreferences(),
      facts: facts,
    );

    expect(probed, [HintPlatform.windows]);
    expect(facts.nativeHint, ScreenReaderObservation.positive);
    expect(facts.locality, TerminalLocality.local);
    expect(resolution, isA<ResolvedInteraction>());
    final resolved = resolution as ResolvedInteraction;
    expect(resolved.mode, PromptMode.linear);
    expect(resolved.screenReader, isTrue);
  });

  test('Linux and unsupported platforms never call a reader probe', () async {
    for (final platform in [HintPlatform.linux, HintPlatform.unsupported]) {
      var called = false;
      final facts = await NativeHintObservations(
        platform: platform,
        interactive: true,
        localSessionAttested: true,
        readerProbe: (_) async {
          called = true;
          return ScreenReaderObservation.positive;
        },
      ).facts();

      expect(called, isFalse, reason: '$platform');
      expect(facts.nativeHint, ScreenReaderObservation.unknown);
      final resolution = resolveInteraction(
        preferences: const InteractionPreferences(),
        facts: facts,
      );
      expect((resolution as ResolvedInteraction).screenReader, isFalse);
    }
  });

  test(
    'a failed reader observation is carried but never selects or vetoes',
    () async {
      final failed = await NativeHintObservations(
        platform: HintPlatform.macos,
        interactive: true,
        localSessionAttested: true,
        readerProbe: (_) => throw StateError('native query failed'),
      ).facts();
      expect(failed.nativeHint, ScreenReaderObservation.failed);

      final failedResolution = resolveInteraction(
        preferences: const InteractionPreferences(),
        facts: failed,
      );
      expect((failedResolution as ResolvedInteraction).screenReader, isFalse);

      final negative = await NativeHintObservations(
        platform: HintPlatform.windows,
        interactive: true,
        localSessionAttested: true,
        readerProbe: (_) => ScreenReaderObservation.negative,
      ).facts();
      final appHintResolution = resolveInteraction(
        preferences: const InteractionPreferences(
          applicationHint: ScreenReaderObservation.positive,
        ),
        facts: negative,
      );
      expect(negative.nativeHint, ScreenReaderObservation.negative);
      expect((appHintResolution as ResolvedInteraction).screenReader, isTrue);
    },
  );

  test('platform names map to documented families only', () {
    expect(platformFromName('Windows'), HintPlatform.windows);
    expect(platformFromName('macos'), HintPlatform.macos);
    expect(platformFromName('linux'), HintPlatform.linux);
    expect(platformFromName('freebsd'), HintPlatform.unsupported);
  });
}
