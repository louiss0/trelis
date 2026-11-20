import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

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
  _RecordingTerminal(this.input, this.output, this.events);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  @override
  bool get supportsRich => false;
  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() => events.add('restore'));
  }
}

TerminalEnvironment _recordingEnvironment(
  StringSink output,
  List<String> events, {
  Stream<String>? input,
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events,
  ),
  profile: const OutputProfile(glyphs: GlyphSet.ascii),
);
