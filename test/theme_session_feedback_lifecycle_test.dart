import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test(
    'prompt completion keeps feedback active until its last participant ends',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final started = Completer<void>();
      final releaseFeedback = Completer<void>();
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(
          _RecordingTerminal(Stream.value('Ada\r'), output, events),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      late final Spinner spinner;
      final feedback = owner.feedback((handle) async {
        spinner = Spinner('Index')..start(session: handle.session);
        Text('Ready').present(session: handle.session);
        started.complete();
        await releaseFeedback.future;
        spinner.dispose();
        return 'stopped';
      });
      await started.future;

      final answer = await owner.prompt(
        (handle) => TextInput('Name').prompt(session: handle.session),
      );

      expect((answer as Accepted<String>).value, 'Ada');
      expect(callbacks, 1);
      expect(owner.resolvedInteraction, isNotNull);
      expect(
        events,
        isNot(contains('restore:1')),
        reason: 'the prompt must not clean up while feedback is participating',
      );
      expect(output.toString(), contains('Index: running'));

      releaseFeedback.complete();
      expect(await feedback, 'stopped');
      expect(owner.resolvedInteraction, isNull);
      expect(events.last, 'restore:1');

      final later = await owner.prompt((_) async => Accepted('later'));
      expect((later as Accepted<String>).value, 'later');
      expect(callbacks, 2, reason: 'a later period may resolve again');
    },
  );

  for (final path in ['completed', 'failed', 'stopped']) {
    test('feedback can end through $path and release the period', () async {
      final events = <String>[];
      final output = StringBuffer();
      final started = Completer<void>();
      final releaseFeedback = Completer<void>();
      final owner = ThemeSession(
        environment: _environment(
          _RecordingTerminal(Stream.value('Ada\r'), output, events),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      late final Spinner spinner;
      final feedback = owner.feedback((handle) async {
        spinner = Spinner('Index')..start(session: handle.session);
        started.complete();
        await releaseFeedback.future;
        switch (path) {
          case 'completed':
            spinner.finish(FeedbackOutcome.completed);
          case 'failed':
            spinner.finish(FeedbackOutcome.failed, detail: 'offline');
          case 'stopped':
            spinner.dispose();
        }
        return path;
      });
      await started.future;

      final answer = await owner.prompt(
        (handle) => TextInput('Name').prompt(session: handle.session),
      );

      expect((answer as Accepted<String>).value, 'Ada');
      expect(events, isNot(contains('restore:1')));

      releaseFeedback.complete();
      expect(await feedback, path);
      expect(owner.resolvedInteraction, isNull);
      expect(events.last, 'restore:1');
      switch (path) {
        case 'completed':
          expect(output.toString(), contains('Index: completed'));
        case 'failed':
          expect(output.toString(), contains('Index: failed: offline'));
        case 'stopped':
          expect(output.toString(), isNot(contains('Index: completed')));
      }
    });
  }

  test(
    'a feedback failure releases its participation without losing the prompt',
    () async {
      final events = <String>[];
      final failure = StateError('feedback failed');
      final started = Completer<void>();
      final releaseFeedback = Completer<void>();
      final owner = ThemeSession(
        environment: _environment(
          _RecordingTerminal(Stream.value('Ada\r'), StringBuffer(), events),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final feedback = owner.feedback((_) async {
        started.complete();
        await releaseFeedback.future;
        throw failure;
      });
      await started.future;

      final answer = await owner.prompt(
        (handle) => TextInput('Name').prompt(session: handle.session),
      );
      expect((answer as Accepted<String>).value, 'Ada');
      expect(events, isNot(contains('restore:1')));

      releaseFeedback.complete();
      await expectLater(feedback, throwsA(same(failure)));
      expect(owner.resolvedInteraction, isNull);
      expect(events.last, 'restore:1');
    },
  );
}

TerminalEnvironment _environment(TerminalIo terminal) =>
    TerminalEnvironment.custom(
      adapter: terminal,
      profile: const OutputProfile(glyphs: GlyphSet.ascii),
    );

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events);

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  var _acquired = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    _acquired++;
    final number = _acquired;
    events.add('acquire:$number');
    return TerminalLease(() => events.add('restore:$number'));
  }
}
