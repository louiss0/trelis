import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'observations are cached for one period and repeated after cleanup',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      var probeCalls = 0;
      var nativePositive = true;
      final started = Completer<void>();
      final release = Completer<void>();
      final observed = <ResolvedInteraction>[];
      final owner = ThemeSession(
        environment: _environment(output, events),
        interaction: const InteractionPreferences(),
        hints: NativeHintObservations(
          platform: HintPlatform.windows,
          interactive: true,
          localSessionAttested: true,
          readerProbe: (_) {
            probeCalls++;
            events.add('probe');
            return nativePositive
                ? ScreenReaderObservation.positive
                : ScreenReaderObservation.negative;
          },
        ),
        onResolved: (interaction) async {
          events.add('callback');
          observed.add(interaction);
        },
      );

      final first = owner.prompt((handle) async {
        output.write('first');
        started.complete();
        await release.future;
        return Accepted('one');
      });
      await started.future;
      await owner.feedback((handle) async {
        output.write('feedback');
        return null;
      });

      expect(probeCalls, 1);
      expect(observed, hasLength(1));
      expect(observed.single.screenReader, isTrue);

      release.complete();
      await first;
      expect(events.last, 'restore');
      expect(owner.resolvedInteraction, isNull);

      nativePositive = false;
      final second = await owner.prompt((handle) async {
        output.write('second');
        return Accepted('two');
      });

      expect(second, isA<Accepted<String>>());
      expect(probeCalls, 2);
      expect(observed, hasLength(2));
      expect(observed.last.screenReader, isFalse);
      expect(events.where((event) => event == 'probe'), hasLength(2));
    },
  );

  test(
    'explicit preferences still take precedence over injected hints',
    () async {
      final cases =
          <
            ({
              String name,
              InteractionPreferences preferences,
              ScreenReaderObservation nativeHint,
              bool supportsRich,
              bool expectedScreenReader,
              PromptMode expectedMode,
            })
          >[
            (
              name:
                  'explicit off defeats positive application and native hints',
              preferences: const InteractionPreferences(
                screenReader: ScreenReaderPreference.off,
                applicationHint: ScreenReaderObservation.positive,
              ),
              nativeHint: ScreenReaderObservation.positive,
              supportsRich: false,
              expectedScreenReader: false,
              expectedMode: PromptMode.linear,
            ),
            (
              name: 'positive application hint survives a negative native hint',
              preferences: const InteractionPreferences(
                applicationHint: ScreenReaderObservation.positive,
              ),
              nativeHint: ScreenReaderObservation.negative,
              supportsRich: false,
              expectedScreenReader: true,
              expectedMode: PromptMode.linear,
            ),
            (
              name: 'explicit on selects linear even when native query failed',
              preferences: const InteractionPreferences(
                screenReader: ScreenReaderPreference.on,
              ),
              nativeHint: ScreenReaderObservation.failed,
              supportsRich: false,
              expectedScreenReader: true,
              expectedMode: PromptMode.linear,
            ),
            (
              name: 'explicit rich is not overridden by affirmative hints',
              preferences: const InteractionPreferences(
                mode: PromptMode.rich,
                applicationHint: ScreenReaderObservation.positive,
              ),
              nativeHint: ScreenReaderObservation.positive,
              supportsRich: true,
              expectedScreenReader: false,
              expectedMode: PromptMode.rich,
            ),
          ];

      for (final entry in cases) {
        final events = <String>[];
        ResolvedInteraction? resolved;
        final owner = ThemeSession(
          environment: _environment(
            _RecordingSink(events),
            events,
            supportsRich: entry.supportsRich,
          ),
          interaction: entry.preferences,
          hints: NativeHintObservations(
            platform: HintPlatform.macos,
            interactive: true,
            localSessionAttested: true,
            readerProbe: (_) => entry.nativeHint,
          ),
          onResolved: (interaction) async => resolved = interaction,
        );

        final result = await owner.prompt((handle) async => Accepted('ok'));

        expect(result, isA<Accepted<String>>(), reason: entry.name);
        expect(resolved, isNotNull, reason: entry.name);
        expect(
          resolved!.screenReader,
          entry.expectedScreenReader,
          reason: entry.name,
        );
        expect(resolved!.mode, entry.expectedMode, reason: entry.name);
      }
    },
  );

  test('terminal environment indicators reach the observation seam', () async {
    final events = <String>[];
    ResolvedInteraction? resolved;
    final owner = ThemeSession(
      environment: _environment(
        _RecordingSink(events),
        events,
        environment: const {'SSH_CONNECTION': '10.0.0.1 50000 10.0.0.2 22'},
      ),
      interaction: const InteractionPreferences(),
      hints: NativeHintObservations(
        platform: HintPlatform.windows,
        interactive: true,
        localSessionAttested: true,
        readerProbe: (_) => ScreenReaderObservation.positive,
      ),
      onResolved: (interaction) async => resolved = interaction,
    );

    final result = await owner.prompt((handle) async => Accepted('ok'));

    expect(result, isA<Accepted<String>>());
    expect(resolved, isNotNull);
    expect(resolved!.screenReader, isFalse);
  });

  test('a conflict never observes or renders', () async {
    final events = <String>[];
    final owner = ThemeSession(
      environment: _environment(_RecordingSink(events), events),
      interaction: const InteractionPreferences(
        mode: PromptMode.rich,
        screenReader: ScreenReaderPreference.on,
      ),
      hints: NativeHintObservations(
        platform: HintPlatform.windows,
        interactive: true,
        localSessionAttested: true,
        readerProbe: (_) {
          events.add('probe');
          return ScreenReaderObservation.positive;
        },
      ),
      onResolved: (_) async => events.add('callback'),
    );

    final result = await owner.prompt(
      (handle) async => Accepted('unreachable'),
    );

    expect(result, isA<Unavailable<String>>());
    expect(
      (result as Unavailable<String>).reason,
      contains('cannot be combined'),
    );
    expect(events, isEmpty);
  });
}

final class _RecordingSink implements StringSink {
  _RecordingSink(this.events);

  final List<String> events;

  @override
  void write(Object? object) => events.add('write:$object');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    for (final object in objects) {
      write(object);
      if (separator.isNotEmpty) write(separator);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }
}

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events, this.environment);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  @override
  final Map<String, String?> environment;

  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

TerminalEnvironment _environment(
  StringSink output,
  List<String> events, {
  bool supportsRich = false,
  Map<String, String?> environment = const <String, String?>{},
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    const Stream<String>.empty(),
    output,
    events,
    environment,
  ),
  profile: supportsRich
      ? OutputProfile(
          cursor: CapabilitySupport.supported,
          geometry: OutputGeometry.fixed(columns: 80, rows: 24),
        )
      : const OutputProfile(glyphs: GlyphSet.ascii),
);
