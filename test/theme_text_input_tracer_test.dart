import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/background_query.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/src/testing/compat_api.dart';

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

  test(
    'a callback failure restores resources and permits a later prompt',
    () async {
      final events = <String>[];
      final failure = StateError('callback refused');
      var callbacks = 0;
      final tracer = ThemeTextInputTracer(
        'Name',
        io: TerminalEnvironment.custom(
          adapter: _LifecycleTerminal(
            Stream.value('Ada\r'),
            StringBuffer(),
            events,
          ),
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          callbacks++;
          if (callbacks == 1) throw failure;
        },
      );

      await expectLater(tracer.prompt(), throwsA(same(failure)));
      expect(events, ['acquire', 'restore']);
      expect(callbacks, 1);

      expect((await tracer.prompt() as Accepted<String>).value, 'Ada');
      expect(events, [
        'acquire',
        'restore',
        'acquire',
        'acquire',
        'restore',
        'restore',
      ]);
      expect(callbacks, 2);
    },
  );

  test('an output failure reaches the caller after restoration', () async {
    final events = <String>[];
    final sink = _FailingSink(events);
    var callbacks = 0;
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.custom(
        adapter: _LifecycleTerminal(const Stream<String>.empty(), sink, events),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      onResolved: (_) async => callbacks++,
    );

    await expectLater(tracer.prompt(), throwsA(same(sink.failure)));
    expect(events, ['acquire', 'acquire', 'restore', 'restore']);
    expect(callbacks, 1);
  });

  test('a cleanup failure is observable without losing the answer', () async {
    final events = <String>[];
    final failure = StateError('restore failed');
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.custom(
        adapter: _LifecycleTerminal(
          Stream.value('Ada\r'),
          StringBuffer(),
          events,
          restoreError: failure,
          failingRestore: 2,
        ),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, 'Ada');
    expect(tracer.cleanupFailures, [same(failure)]);
    expect(events, ['acquire', 'acquire', 'restore']);
  });

  test('NO_COLOR keeps a successful redirected prompt plain', () async {
    final events = <String>[];
    final output = StringBuffer();
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.custom(
        adapter: _LifecycleTerminal(
          Stream.value('Ada\r'),
          output,
          events,
          noColor: '1',
        ),
        profile: _richProfile,
        environment: const {'NO_COLOR': '1'},
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      colors: ComponentColors.palette(
        ColorThemes.terminalDefault.copyWith(
          foreground: TerminalColor.rgb(9, 8, 7),
        ),
      ),
      themeColors: const ColorPreferences(
        background: BackgroundPreference.dark,
      ),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, 'Ada');
    expect(output.toString(), contains('Name'));
    expect(output.toString(), isNot(contains('\x1b[38;')));
    expect(output.toString(), isNot(contains(osc11BackgroundRequest)));
    expect(events, ['acquire', 'acquire', 'restore', 'restore']);
  });

  test('explicit rich fails without output on a redirected sink', () async {
    final events = <String>[];
    final output = StringBuffer();
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.custom(
        adapter: _LifecycleTerminal(Stream.value('Ada\r'), output, events),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    );

    final result = await tracer.prompt();

    expect(result, isA<Unavailable<String>>());
    expect(output.toString(), isEmpty);
    expect(events, isEmpty);
  });

  test('caller streams stay open after a traced prompt', () async {
    var cancellations = 0;
    final input = StreamController<String>(onCancel: () => cancellations++);
    input.add('Ada\r');
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.scripted(
        input: input.stream,
        output: StringBuffer(),
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    expect((await tracer.prompt() as Accepted<String>).value, 'Ada');
    expect(input.isClosed, isFalse);
    expect(cancellations, greaterThan(0));
    await input.close();
  });

  test('an escaped command stays literal across a validation retry', () async {
    final output = StringBuffer();
    final tracer = ThemeTextInputTracer(
      'Name',
      io: TerminalEnvironment.scripted(
        input: Stream.value('\r\\/cancel\r'),
        output: output,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      required: true,
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, '/cancel');
    expect(output.toString(), contains('Required'));
    expect(output.toString(), isNot(contains('Help:')));
  });

  test(
    'a multiline paste is rejected while the existing draft survives',
    () async {
      final output = StringBuffer();
      final tracer = ThemeTextInputTracer(
        'Name',
        initialValue: 'seed',
        io: TerminalEnvironment.scripted(
          input: Stream.value('\x1b[200~line1\nline2\x1b[201~X\r'),
          output: output,
          profile: const OutputProfile(glyphs: GlyphSet.ascii),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );

      final result = await tracer.prompt();

      expect((result as Accepted<String>).value, 'seedX');
      expect(
        output.toString(),
        contains('Paste rejected: single-line printable text only.'),
      );
    },
  );

  test('a secret prompt keeps its value out of the traced output', () async {
    const canary = 'password-canary-73';
    final output = StringBuffer();
    final tracer = ThemeTextInputTracer(
      'Password',
      secret: true,
      io: TerminalEnvironment.scripted(
        input: Stream.value('$canary\x1bOP\x1b\rsubmit\r'),
        output: output,
        profile: const OutputProfile(glyphs: GlyphSet.ascii),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, canary);
    expect(output.toString(), contains('Hidden entry'));
    expect(output.toString(), isNot(contains(canary)));
    expect(output.toString(), isNot(contains('${canary.length} graphemes')));
  });
}

final class _LifecycleTerminal implements TerminalIo {
  _LifecycleTerminal(
    this.input,
    this.output,
    this.events, {
    this.restoreError,
    this.noColor,
    this.failingRestore,
  });

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  final Object? restoreError;
  final String? noColor;
  final int? failingRestore;
  var _restores = 0;

  @override
  bool get supportsRich => false;

  @override
  Map<String, String?> get environment =>
      noColor == null ? const <String, String?>{} : {'NO_COLOR': noColor};

  @override
  TerminalLease acquire() {
    events.add('acquire');
    return TerminalLease(() {
      final number = ++_restores;
      if (restoreError != null && number == failingRestore) {
        throw restoreError!;
      }
      events.add('restore');
    });
  }
}

final class _FailingSink implements StringSink {
  _FailingSink(this.events);

  final List<String> events;
  final Object failure = StateError('writer failed');

  @override
  void write(Object? object) {
    if (object.toString().contains('Name')) {
      Error.throwWithStackTrace(failure, StackTrace.empty);
    }
    events.add('write:$object');
  }

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
