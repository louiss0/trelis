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

  test('SSH, tmux and screen indicators block native reader hints', () async {
    final cases = <({String key, TerminalLocality locality})>[
      (key: 'SSH_CONNECTION', locality: TerminalLocality.remote),
      (key: 'SSH_CLIENT', locality: TerminalLocality.remote),
      (key: 'SSH_TTY', locality: TerminalLocality.remote),
      (key: 'TMUX', locality: TerminalLocality.ambiguous),
      (key: 'TMUX_PANE', locality: TerminalLocality.ambiguous),
      (key: 'STY', locality: TerminalLocality.ambiguous),
      (key: 'WINDOW', locality: TerminalLocality.ambiguous),
    ];
    for (final entry in cases) {
      final facts = await NativeHintObservations(
        platform: HintPlatform.windows,
        interactive: true,
        localSessionAttested: true,
        environment: {entry.key: 'non-empty'},
        readerProbe: (_) => ScreenReaderObservation.positive,
      ).facts(output: _richOutput);

      expect(facts.locality, entry.locality, reason: entry.key);
      expect(facts.nativeHint, ScreenReaderObservation.positive);
      final resolution = resolveInteraction(
        preferences: const InteractionPreferences(),
        facts: facts,
      );
      expect(
        (resolution as ResolvedInteraction).screenReader,
        isFalse,
        reason: entry.key,
      );
    }
  });

  test('RDP and failed required locality checks are never local', () async {
    final remote = await _facts(
      remoteSessionProbe: (_) => RemoteSessionObservation.remote,
    );
    expect(remote.locality, TerminalLocality.remote);
    expect(await _screenReader(remote), isFalse);

    final failed = await _facts(
      remoteSessionProbe: (_) => RemoteSessionObservation.failed,
    );
    expect(failed.locality, TerminalLocality.ambiguous);
    expect(await _screenReader(failed), isFalse);

    final threw = await _facts(
      remoteSessionProbe: (_) => throw StateError('WTS query failed'),
    );
    expect(threw.locality, TerminalLocality.ambiguous);

    for (final neutral in [
      RemoteSessionObservation.notRemote,
      RemoteSessionObservation.unavailable,
      RemoteSessionObservation.unknown,
    ]) {
      final facts = await _facts(remoteSessionProbe: (_) => neutral);
      expect(facts.locality, TerminalLocality.local, reason: '$neutral');
      expect(await _screenReader(facts), isTrue, reason: '$neutral');
    }
  });

  test(
    'container indicators are ambiguous but unavailable checks are not',
    () async {
      final fromEnvironment = await _facts(
        environment: const {'container': 'docker'},
      );
      expect(fromEnvironment.locality, TerminalLocality.ambiguous);
      expect(await _screenReader(fromEnvironment), isFalse);

      final detected = await _facts(
        containerProbe: () => ContainerObservation.detected,
      );
      expect(detected.locality, TerminalLocality.ambiguous);

      for (final neutral in [
        ContainerObservation.absent,
        ContainerObservation.unavailable,
        ContainerObservation.unknown,
      ]) {
        final facts = await _facts(containerProbe: () => neutral);
        expect(facts.locality, TerminalLocality.local, reason: '$neutral');
        expect(await _screenReader(facts), isTrue, reason: '$neutral');
      }

      final failedProbe = await _facts(
        containerProbe: () => throw StateError('container check failed'),
      );
      expect(failedProbe.locality, TerminalLocality.local);
      expect(await _screenReader(failedProbe), isTrue);
    },
  );

  test('absence of indicators is not proof of locality', () async {
    final unattested = await _facts(localSessionAttested: false);
    expect(unattested.locality, TerminalLocality.unknown);
    expect(await _screenReader(unattested), isFalse);

    final noninteractive = await _facts(interactive: false);
    expect(noninteractive.locality, TerminalLocality.unknown);
    expect(await _screenReader(noninteractive), isFalse);

    final appHint = resolveInteraction(
      preferences: const InteractionPreferences(
        applicationHint: ScreenReaderObservation.positive,
      ),
      facts: noninteractive,
    );
    expect((appHint as ResolvedInteraction).screenReader, isTrue);
  });

  test('platform names map to documented families only', () {
    expect(platformFromName('Windows'), HintPlatform.windows);
    expect(platformFromName('macos'), HintPlatform.macos);
    expect(platformFromName('linux'), HintPlatform.linux);
    expect(platformFromName('freebsd'), HintPlatform.unsupported);
  });
}

Future<InteractionFacts> _facts({
  Map<String, String?> environment = const <String, String?>{},
  bool interactive = true,
  bool localSessionAttested = true,
  RemoteSessionProbe? remoteSessionProbe,
  ContainerProbe? containerProbe,
}) => NativeHintObservations(
  platform: HintPlatform.windows,
  environment: environment,
  interactive: interactive,
  localSessionAttested: localSessionAttested,
  readerProbe: (_) => ScreenReaderObservation.positive,
  remoteSessionProbe: remoteSessionProbe,
  containerProbe: containerProbe,
).facts(output: _richOutput);

Future<bool> _screenReader(InteractionFacts facts) async {
  final resolution = resolveInteraction(
    preferences: const InteractionPreferences(),
    facts: facts,
  );
  return (resolution as ResolvedInteraction).screenReader;
}
