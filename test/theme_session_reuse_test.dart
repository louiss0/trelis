import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  test(
    'sequential prompts reuse a component from its configured initial value',
    () async {
      final output = StringBuffer();
      final owner = ThemeSession(
        environment: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['x\r', '\r']),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final prompt = TextInput('Name', initialValue: 'seed');

      final first = await owner.prompt(
        (handle) => prompt.prompt(session: handle.session),
      );
      final second = await owner.prompt(
        (handle) => prompt.prompt(session: handle.session),
      );

      expect((first as Accepted<String>).value, 'seedx');
      expect((second as Accepted<String>).value, 'seed');
    },
  );

  test('exhausted scripted input ends the prompt with InputEnded', () async {
    final owner = ThemeSession(
      environment: TerminalEnvironment.scripted(
        input: const Stream<String>.empty(),
        output: StringBuffer(),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final result = await owner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );

    expect(result, isA<InputEnded<String>>());
  });

  test('caller streams stay open unless ownership is transferred', () async {
    var cancellations = 0;
    final callerInput = StreamController<String>(
      onCancel: () => cancellations++,
    );
    callerInput.add('Ada\r');
    final owner = ThemeSession(
      environment: TerminalEnvironment.scripted(
        input: callerInput.stream,
        output: StringBuffer(),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final result = await owner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );

    expect((result as Accepted<String>).value, 'Ada');
    expect(callerInput.isClosed, isFalse);
    expect(
      cancellations,
      1,
      reason: 'reader cancellation can still reach caller cleanup behavior',
    );
    await callerInput.close();

    final transferred = StreamController<String>();
    transferred.add('Grace\r');
    final transferredOwner = ThemeSession(
      environment: TerminalEnvironment.scripted(
        input: transferred.stream,
        output: StringBuffer(),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
        closeInput: transferred.close,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final transferredResult = await transferredOwner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );

    expect((transferredResult as Accepted<String>).value, 'Grace');
    expect(transferred.isClosed, isTrue);
  });
}

/// Gives each prompt subscription its own scripted answer.
final class _AnswersPerListen extends Stream<String> {
  _AnswersPerListen(this._answers);

  final List<String> _answers;
  var _next = 0;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final answer = _answers[_next++];
    return Stream<String>.value(answer).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
