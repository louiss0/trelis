import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/trelis.dart';

void main() {
  test('rich text input renders its resolved component palette to the selected output', () async {
    final output = StringBuffer();
    final environment = TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: output,
      profile: _richProfile,
      supportsRich: true,
    );
    final palette = ColorThemes.terminalDefault.copyWith(
      foreground: TerminalColor.rgb(9, 8, 7),
      background: TerminalColor.rgb(1, 2, 3),
    );
    final tracer = ThemeTextInputTracer(
      'Name',
      io: environment,
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: ComponentColors.palette(palette),
      themeColors: const ColorPreferences(
        background: BackgroundPreference.dark,
      ),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), contains('Name'));
    expect(
      output.toString(),
      contains('\x1b[38;2;9;8;7;48;2;1;2;3mName (Optional).'),
    );
  });

  test(
    'linear input and live feedback share one period on the selected output',
    () async {
      final output = StringBuffer();
      final input = StreamController<String>();
      var callbacks = 0;
      final tracer = ThemeTextInputTracer(
        'Name',
        io: TerminalEnvironment.scripted(
          input: input.stream,
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async => callbacks++,
      );

      late final Spinner index;
      final feedback = await tracer.startFeedback((handle) {
        index = Spinner('Index')..start(session: handle.session);
      }, stop: () => index.dispose());
      final pending = tracer.prompt();
      await _waitUntil(() => output.toString().contains('Name'));
      input.add('Ada\r');
      await input.close();

      expect((await pending as Accepted<String>).value, 'Ada');
      await feedback.finish(() => index.finish(FeedbackOutcome.completed));

      expect(output.toString(), contains('Index'));
      expect(output.toString(), contains('Index: completed'));
      expect(output.toString(), isNot(contains('\x1b[?1049h')));
      expect(callbacks, 1, reason: 'prompt and feedback share one callback');
    },
  );

  test(
    'sequential prompts reset the initial value and resolve a fresh period',
    () async {
      final facts = <String>[];
      var callbacks = 0;
      final tracer = ThemeTextInputTracer(
        'Name',
        initialValue: 'seed',
        io: TerminalEnvironment.scripted(
          input: _AnswersPerListen(['x\r', '\r']),
          output: StringBuffer(),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        themeColors: const ColorPreferences(
          background: BackgroundPreference.dark,
        ),
        factsForPeriod: (_) async {
          facts.add('facts');
          return const InteractionFacts();
        },
        onResolved: (_) async => callbacks++,
      );

      final first = await tracer.prompt();
      final second = await tracer.prompt();

      expect((first as Accepted<String>).value, 'seedx');
      expect((second as Accepted<String>).value, 'seed');
      expect(facts, hasLength(2));
      expect(callbacks, 2);
    },
  );

  test(
    'exhausted scripted input ends the traced prompt with InputEnded',
    () async {
      final tracer = ThemeTextInputTracer(
        'Name',
        io: TerminalEnvironment.scripted(
          input: const Stream<String>.empty(),
          output: StringBuffer(),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      expect(await tracer.prompt(), isA<InputEnded<String>>());
    },
  );

  test('a second concurrent prompt is rejected without rendering', () async {
    final output = StringBuffer();
    final input = StreamController<String>();
    var callbacks = 0;
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.scripted(
        input: input.stream,
        output: output,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      onResolved: (_) async => callbacks++,
    );

    final pending = tracer.prompt();
    await _waitUntil(() => output.toString().contains('Name'));
    final rejected = await tracer.prompt();

    expect(rejected, isA<Unavailable<String>>());
    expect(
      (rejected as Unavailable<String>).reason,
      contains('already active'),
    );
    expect(callbacks, 1);
    expect(RegExp('Name').allMatches(output.toString()), hasLength(1));

    input.add('Ada\r');
    await input.close();
    expect((await pending as Accepted<String>).value, 'Ada');
  });
}

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

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition was not met before the test deadline');
}

final _richProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
);
