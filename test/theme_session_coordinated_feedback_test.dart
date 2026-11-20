import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/trelis.dart';

void main() {
  test('one-shot feedback waits for asynchronous detection before its first output', () async {
    final events = <String>[];
    final output = StringBuffer();
    final facts = Completer<InteractionFacts>();
    final owner = ThemeSession(
      environment: _environment(output, events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      factsForPeriod: (_) => facts.future,
      onResolved: (_) async => events.add('callback'),
    );

    final pending = owner.presentFeedback(Text('Ready'));
    await _pump();
    expect(output.toString(), isEmpty);
    expect(events, isEmpty);

    facts.complete(const InteractionFacts());
    await pending;

    expect(output.toString(), contains('Ready'));
    expect(events, ['acquire:1', 'callback', 'restore:1']);
    expect(owner.resolvedInteraction, isNull);
  });

  test(
    'multiple live feedback instances share one prompt period and cleanup',
    () async {
      final events = <String>[];
      final output = StringBuffer();
      final input = StreamController<String>();
      var facts = 0;
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(output, events, input: input.stream),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) async {
          facts++;
          return const InteractionFacts();
        },
        onResolved: (_) async {
          callbacks++;
          events.add('callback:$callbacks');
        },
      );

      late final Spinner index;
      final first = await owner.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      late final Progress upload;
      final second = await owner.startFeedback((handle) {
        upload = Progress('Upload', total: 2)..start(session: handle.session);
      }, stop: () => upload.dispose());

      final promptStarted = Completer<void>();
      final prompt = owner.prompt((handle) async {
        promptStarted.complete();
        return await TextInput('Name').prompt(session: handle.session);
      });
      await promptStarted.future;
      input.add('Ada\r');
      await input.close();

      await first.finish(() => index.finish(FeedbackOutcome.completed));
      expect(events, isNot(contains('restore:1')));
      expect(owner.resolvedInteraction, isNotNull);
      await second.finish(() => upload.finish(FeedbackOutcome.failed));
      expect(events, contains('restore:1'));
      expect(owner.resolvedInteraction, isNull);

      expect((await prompt as Accepted<String>).value, 'Ada');
      expect(events.where((event) => event.startsWith('acquire')), [
        'acquire:1',
        'acquire:2',
      ], reason: 'the period and the prompt each acquire a lease');
      expect(events.last, 'restore:1');
      expect(facts, 1);
      expect(callbacks, 1);
      expect(output.toString(), contains('Index: completed'));
      expect(output.toString(), contains('Upload: failed'));

      await owner.presentFeedback(Text('Later'));
      expect(facts, 2);
      expect(callbacks, 2);
      expect(events.last, 'restore:3');
    },
  );
}

Future<void> _pump([int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

TerminalEnvironment _environment(
  StringSink output,
  List<String> events, {
  Stream<String>? input,
  Object? ownershipIdentity,
  Object? restoreError,
  OutputProfile profile = const OutputProfile(glyphs: GlyphSet.ascii),
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events,
    restoreError: restoreError,
  ),
  profile: profile,
  ownershipIdentity: ownershipIdentity,
);

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(this.input, this.output, this.events, {this.restoreError});

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  final Object? restoreError;
  var _acquired = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment => const <String, String?>{};

  @override
  TerminalLease acquire() {
    final number = ++_acquired;
    events.add('acquire:$number');
    return TerminalLease(() {
      if (restoreError != null) throw restoreError!;
      events.add('restore:$number');
    });
  }
}
