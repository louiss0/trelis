import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  test(
    'prompt-first initialization acquires and resolves before output',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final environment = _recordingEnvironment(output, events);
      final owner = ThemeSession(
        environment: environment,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => events.add('callback'),
      );

      final result = await owner.prompt((handle) async {
        expect(owner.resolvedInteraction?.mode, PromptMode.linear);
        output.write('prompt');
        return Accepted('ok');
      });

      expect(result, isA<Accepted<String>>());
      expect(events, ['acquire', 'callback', 'write:prompt', 'restore']);
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test(
    'feedback-first initialization acquires and resolves before output',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final environment = _recordingEnvironment(output, events);
      final owner = ThemeSession(
        environment: environment,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => events.add('callback'),
      );

      final seen = await owner.feedback((handle) async {
        expect(owner.resolvedInteraction?.mode, PromptMode.linear);
        output.write('feedback');
        return 'started';
      });

      expect(seen, 'started');
      expect(events, ['acquire', 'callback', 'write:feedback', 'restore']);
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test('a theme-wide conflict prevents prompt and feedback output', () async {
    final events = <String>[];
    final output = _RecordingSink(events);
    final owner = ThemeSession(
      environment: _recordingEnvironment(output, events),
      interaction: const InteractionPreferences(
        mode: PromptMode.rich,
        screenReader: ScreenReaderPreference.on,
      ),
      onResolved: (_) async => events.add('callback'),
    );

    final result = await owner.prompt((_) async => Accepted('unreachable'));

    expect(result, isA<Unavailable<String>>());
    expect(
      (result as Unavailable<String>).reason,
      contains('cannot be combined'),
    );
    await expectLater(
      owner.feedback((_) async => 'unreachable'),
      throwsA(
        isA<ThemeSessionUnavailable>().having(
          (error) => error.reason,
          'reason',
          contains('cannot be combined'),
        ),
      ),
    );
    expect(events, isEmpty);
    expect(owner.resolvedInteraction, isNull);
  });

  test(
    'unavailable explicit rich keeps output empty and skips the callback',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        onResolved: (_) async => events.add('callback'),
      );

      final result = await owner.prompt((_) async => Accepted('unreachable'));

      expect(result, isA<Unavailable<String>>());
      expect(
        (result as Unavailable<String>).reason,
        contains('unavailable on the selected output'),
      );
      await expectLater(
        owner.feedback((_) async => 'unreachable'),
        throwsA(
          isA<ThemeSessionUnavailable>().having(
            (error) => error.reason,
            'reason',
            contains('unavailable on the selected output'),
          ),
        ),
      );
      expect(events, isEmpty);
    },
  );

  test(
    'a component availability failure is checked before publication',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => events.add('callback'),
      );
      const unavailable = ThemeComponentAvailability(
        prompt: false,
        feedback: false,
        reason: 'component cannot render here',
      );

      final result = await owner.prompt(
        (_) async => Accepted('unreachable'),
        availability: unavailable,
      );

      expect(result, isA<Unavailable<String>>());
      expect(
        (result as Unavailable<String>).reason,
        'component cannot render here',
      );
      await expectLater(
        owner.feedback((_) async => 'unreachable', availability: unavailable),
        throwsA(
          isA<ThemeSessionUnavailable>().having(
            (error) => error.reason,
            'reason',
            'component cannot render here',
          ),
        ),
      );
      expect(events, isEmpty);
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test(
    'the callback runs once per period and internal delegation stays inside',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      var callbacks = 0;
      final started = Completer<void>();
      final release = Completer<void>();
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          events.add('callback');
        },
      );

      final first = owner.prompt((handle) async {
        output.write('first');
        final nested = await handle.delegate((_) async {
          output.write('nested');
          return 'nested';
        });
        expect(nested, 'nested');
        started.complete();
        await release.future;
        return Accepted('one');
      });
      await started.future;

      await owner.feedback((handle) async {
        output.write('feedback');
        return null;
      });
      expect(callbacks, 1);
      expect(events, [
        'acquire',
        'callback',
        'write:first',
        'write:nested',
        'write:feedback',
      ]);

      release.complete();
      await first;
      expect(events.last, 'restore');
      expect(owner.resolvedInteraction, isNull);

      await owner.prompt((handle) async {
        output.write('later');
        return Accepted('two');
      });
      expect(callbacks, 2);
    },
  );

  test(
    'a callback failure restores resources and permits a later attempt',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final failure = StateError('callback refused');
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          events.add('callback');
          if (callbacks == 1) throw failure;
        },
      );

      await expectLater(
        owner.prompt((handle) async {
          output.write('unreachable');
          return Accepted('no');
        }),
        throwsA(same(failure)),
      );
      expect(events, ['acquire', 'callback', 'restore']);
      expect(owner.resolvedInteraction, isNull);

      final result = await owner.prompt((handle) async {
        output.write('again');
        return Accepted('yes');
      });
      expect((result as Accepted<String>).value, 'yes');
      expect(callbacks, 2);
      expect(events, [
        'acquire',
        'callback',
        'restore',
        'acquire',
        'callback',
        'write:again',
        'restore',
      ]);
    },
  );

  test('acquisition failure never renders or calls the callback', () async {
    final events = <String>[];
    final output = _RecordingSink(events);
    final failure = StateError('cannot acquire');
    var callbacks = 0;
    final owner = ThemeSession(
      environment: _recordingEnvironment(output, events, acquireError: failure),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      onResolved: (_) async {
        callbacks++;
      },
    );

    await expectLater(
      owner.prompt((_) async => Accepted('unreachable')),
      throwsA(same(failure)),
    );
    await expectLater(
      owner.feedback((_) async => 'unreachable'),
      throwsA(same(failure)),
    );

    expect(events, ['acquire', 'acquire']);
    expect(callbacks, 0);
    expect(owner.resolvedInteraction, isNull);
  });

  test(
    'cancellation during initialization publishes nothing and keeps no lease',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final facts = Completer<InteractionFacts>();
      final cancel = Completer<void>();
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) => facts.future,
        onResolved: (_) async {
          callbacks++;
        },
      );

      final pending = owner.prompt((handle) async {
        output.write('unreachable');
        return Accepted('no');
      }, cancellation: cancel.future);
      await Future<void>.delayed(Duration.zero);
      cancel.complete();

      expect(await pending, isA<Cancelled<String>>());
      expect(callbacks, 0);
      expect(events, isEmpty);
      expect(owner.resolvedInteraction, isNull);
      facts.complete(const InteractionFacts());
    },
  );

  test(
    'a failed facts provider falls back before acquiring resources',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        factsForPeriod: (_) => throw StateError('hint source failed'),
        onResolved: (_) async => events.add('callback'),
      );

      final result = await owner.prompt((handle) async {
        expect(owner.resolvedInteraction?.mode, PromptMode.linear);
        expect(owner.resolvedInteraction?.screenReader, isFalse);
        output.write('fallback');
        return Accepted('ok');
      });

      expect((result as Accepted<String>).value, 'ok');
      expect(events, ['acquire', 'callback', 'write:fallback', 'restore']);
    },
  );

  test(
    'injected positive facts publish linear screen-reader interaction',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final owner = ThemeSession(
        environment: _recordingEnvironment(output, events),
        interaction: const InteractionPreferences(
          applicationHint: ScreenReaderObservation.positive,
        ),
        factsForPeriod: (_) => const InteractionFacts(
          nativeHint: ScreenReaderObservation.positive,
          locality: TerminalLocality.local,
          interactive: true,
        ),
        onResolved: (interaction) async {
          expect(interaction.mode, PromptMode.linear);
          expect(interaction.screenReader, isTrue);
          events.add('callback');
        },
      );

      await owner.feedback((handle) async {
        expect(owner.resolvedInteraction?.screenReader, isTrue);
        output.write('linear');
        return null;
      });

      expect(events, ['acquire', 'callback', 'write:linear', 'restore']);
    },
  );

  test(
    'the handle publishes color decisions from the shared resolver',
    () async {
      final events = <String>[];
      final output = _RecordingSink(events);
      final environment = _recordingEnvironment(
        output,
        events,
        environment: const {'NO_COLOR': '1'},
      );
      final owner = ThemeSession(
        environment: environment,
        colors: const ColorPreferences(background: BackgroundPreference.light),
      );

      await owner.prompt((handle) async {
        expect(handle.colors.background, BackgroundVariant.light);
        expect(handle.colors.outputProfile.colorDepth, ColorDepth.none);
        output.write('colored');
        return Accepted('ok');
      });

      expect(events, contains('write:colored'));
      expect(events.last, 'restore');
    },
  );

  test(
    'a real prompt and feedback both render through the owned session',
    () async {
      final output = StringBuffer();
      final environment = TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: output,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      );
      final owner = ThemeSession(
        environment: environment,
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final answer = await owner.prompt(
        (handle) => TextInput('Name').prompt(session: handle.session),
      );
      await owner.feedback((handle) async {
        Text('Ready').present(session: handle.session);
      });

      expect((answer as Accepted<String>).value, 'Ada');
      expect(output.toString(), contains('Name'));
      expect(output.toString(), contains('Ready'));
      expect(owner.resolvedInteraction, isNull);
    },
  );
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
  _RecordingTerminal(
    this.input,
    this.output,
    this.events,
    this.acquireError,
    this.environment,
  );

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  final Object? acquireError;
  @override
  final Map<String, String?> environment;
  @override
  bool get supportsRich => false;

  @override
  TerminalLease acquire() {
    events.add('acquire');
    if (acquireError != null) {
      Error.throwWithStackTrace(acquireError!, StackTrace.empty);
    }
    return TerminalLease(() => events.add('restore'));
  }
}

TerminalEnvironment _recordingEnvironment(
  StringSink output,
  List<String> events, {
  Stream<String>? input,
  Object? acquireError,
  Map<String, String?> environment = const <String, String?>{},
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events,
    acquireError,
    environment,
  ),
  profile: const OutputProfile(glyphs: GlyphSet.ascii),
);
