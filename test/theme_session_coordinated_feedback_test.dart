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
}

Future<void> _pump([int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

TerminalEnvironment _environment(
  StringSink output,
  List<String> events, {
  Object? ownershipIdentity,
  Object? restoreError,
  OutputProfile profile = const OutputProfile(glyphs: GlyphSet.ascii),
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    const Stream<String>.empty(),
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
