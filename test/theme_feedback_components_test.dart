import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
import 'package:trelis/src/theme_feedback_tracer.dart';
import 'package:trelis/src/theme_session.dart';
import 'package:trelis/src/testing/compat_api.dart';

void main() {
  test(
    'one-shot feedback renders a textual Unicode status without help',
    () async {
      final output = StringBuffer();
      final owner = ThemeSession(
        environment: _environment(
          output,
          profile: const OutputProfile(glyphs: GlyphSet.unicode),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final feedback = ThemeFeedbackTracer(owner);

      await feedback.text('Ready', kind: TextKind.success);

      expect(output.toString(), '✓ Success: Ready\n');
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test('ASCII and NO_COLOR keep status labels without colour codes', () async {
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, environment: const {'NO_COLOR': '1'}),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );
    final feedback = ThemeFeedbackTracer(owner);

    await feedback.text('Careful\x1b[31m!', kind: TextKind.warning);
    await feedback.text('Broken', kind: TextKind.error);

    expect(
      output.toString(),
      '! Warning: Careful\\u001b[31m!\nx Error: Broken\n',
    );
    expect(output.toString(), isNot(contains('\x1b[')));
  });

  test('ordinary and hint text stay literal without artificial help', () async {
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );
    final feedback = ThemeFeedbackTracer(owner);

    await feedback.text('Ready');
    await feedback.text('Ctrl+T is data', kind: TextKind.hint);

    expect(output.toString(), 'Ready\nHint: Ctrl+T is data\n');
    expect(output.toString(), isNot(contains('opens help')));
  });

  test('narrow feedback wraps with its status label intact', () async {
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(
        output,
        profile: OutputProfile(
          glyphs: GlyphSet.unicode,
          geometry: OutputGeometry.fixed(columns: 16, rows: 8),
        ),
      ),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    await ThemeFeedbackTracer(owner)
        .text('offline during replication', kind: TextKind.error);

    final lines = output.toString().trimRight().split('\n');
    expect(lines.first, startsWith('× Error:'));
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(16), reason: line);
    }
    expect(output.toString(), contains('replication'));
  });

  test(
    'progress keeps values and distinguishes running from progress',
    () async {
      final output = StringBuffer();
      final owner = ThemeSession(
        environment: _environment(output),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final feedback = ThemeFeedbackTracer(owner);
      final upload = await feedback.progress('Upload', total: 4);

      upload.component.update(2);
      upload.component.phase('hashing');
      upload.component.setTotal(8, completed: 1);
      await upload.finish(FeedbackOutcome.completed);

      final text = output.toString();
      expect(text, contains('Progress: Upload: running, 0%'));
      expect(text, contains('Progress: Upload: running, 50%'));
      expect(text, contains('Running: Upload: running, hashing'));
      expect(text, contains('Progress: Upload: recalculated, 12%'));
      expect(text, contains('+ Success: Upload: completed'));
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test('rich progress renders every exact value in a status region', () async {
    final output = StringBuffer();
    final events = <String>[];
    final owner = ThemeSession(
      environment: _environment(
        output,
        events: events,
        profile: _richProfile(columns: 40, rows: 8),
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(allowBackgroundQuery: false),
    );
    final feedback = ThemeFeedbackTracer(owner);
    final upload = await feedback.progress('Upload', total: 4);
    upload.component.update(2);
    await upload.finish(FeedbackOutcome.failed, detail: 'offline');

    expect(
      output.toString(),
      contains('[status] Progress: Upload: running, 50% (2/4)'),
    );
    expect(
      output.toString(),
      contains('[status] x Error: Upload: failed: offline'),
    );
    expect(events.where((event) => event.startsWith('restore')), ['restore:1']);
  });

  test('screen-reader feedback uses text labels instead of symbols', () async {
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output),
      interaction: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
    );
    final feedback = ThemeFeedbackTracer(owner);
    final index = await feedback.spinner('Index');
    index.component.update('reading cache');
    await index.finish(FeedbackOutcome.completed);

    final text = output.toString();
    expect(text, contains('Running: Index: running'));
    expect(text, contains('Running: Index: reading cache'));
    expect(text, contains('Success: Index: completed'));
    expect(text, isNot(contains('+ Success')));
    expect(text, isNot(contains('✓')));
  });

  test(
    'multi-spinner keeps each task outcome and cancels its cadence',
    () async {
      final output = StringBuffer();
      final clock = _FakeFeedbackClock();
      final owner = ThemeSession(
        environment: _environment(output),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final feedback = ThemeFeedbackTracer(owner);
      final tasks = await feedback.multiSpinner(const [
        'build',
        'test',
      ], clock: clock);
      tasks.component.update('build', TaskActivity.running, phase: 'compiling');
      clock.elapse(const Duration(seconds: 5));
      tasks.component.finishTask('build', FeedbackOutcome.completed);
      tasks.component.finishTask(
        'test',
        FeedbackOutcome.failed,
        detail: 'offline',
      );
      // The last task's outcome closes the group, which releases the
      // participation without an explicit stop.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final text = output.toString();
      expect(text, contains('/ build: running, compiling'));
      expect(text, contains('+ Success: build: completed'));
      expect(text, contains('x Error: test: failed: offline'));
      expect(text, contains('Summary:'));
      expect(clock.timers.every((timer) => timer.cancelled), isTrue);
      expect(owner.resolvedInteraction, isNull);
    },
  );

  test(
    'one-shot feedback waits for resolution before its first output',
    () async {
      final output = StringBuffer();
      final events = <String>[];
      final facts = Completer<InteractionFacts>();
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(output, events: events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        factsForPeriod: (_) => facts.future,
        onResolved: (_) async => callbacks++,
      );

      final pending = ThemeFeedbackTracer(owner).text('After detection');
      await _pump();
      expect(output.toString(), isEmpty);
      expect(events, isEmpty);
      expect(callbacks, 0);

      facts.complete(const InteractionFacts());
      await pending;
      expect(output.toString(), contains('After detection'));
      expect(events, ['acquire:1', 'restore:1']);
      expect(callbacks, 1);
    },
  );

  test('a later period reacquires and re-detects for new feedback', () async {
    final events = <String>[];
    final output = StringBuffer();
    var detections = 0;
    final owner = ThemeSession(
      environment: _environment(output, events: events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
      factsForPeriod: (_) async {
        detections++;
        return const InteractionFacts();
      },
    );
    final feedback = ThemeFeedbackTracer(owner);

    await feedback.text('First');
    await feedback.text('Second');

    expect(detections, 2);
    expect(events, ['acquire:1', 'restore:1', 'acquire:2', 'restore:2']);
    expect(output.toString(), 'First\nSecond\n');
  });

  test(
    'a callback failure publishes nothing and permits later feedback',
    () async {
      final output = StringBuffer();
      final events = <String>[];
      var callbacks = 0;
      final owner = ThemeSession(
        environment: _environment(output, events: events),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        onResolved: (_) async {
          if (++callbacks == 1) throw StateError('callback failed');
        },
      );
      final feedback = ThemeFeedbackTracer(owner);

      await expectLater(
        feedback.text('unreachable'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'callback failed',
          ),
        ),
      );
      expect(output.toString(), isEmpty);
      expect(events, ['acquire:1', 'restore:1']);
      expect(owner.resolvedInteraction, isNull);

      await feedback.text('Later');
      expect(output.toString(), contains('Later'));
      expect(callbacks, 2);
    },
  );

  test(
    'configuration conflicts and unavailable rich mode emit no feedback',
    () async {
      final output = StringBuffer();
      final events = <String>[];
      final conflict = ThemeSession(
        environment: _environment(output, events: events),
        interaction: const InteractionPreferences(
          mode: PromptMode.rich,
          screenReader: ScreenReaderPreference.on,
        ),
      );
      await expectLater(
        ThemeFeedbackTracer(conflict).text('unreachable'),
        throwsA(isA<ThemeSessionUnavailable>()),
      );

      final unavailable = ThemeSession(
        environment: _environment(output, events: events),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
      );
      await expectLater(
        ThemeFeedbackTracer(unavailable).text('unreachable'),
        throwsA(
          isA<ThemeSessionUnavailable>().having(
            (error) => error.reason,
            'reason',
            contains('unavailable on the selected output'),
          ),
        ),
      );
      expect(events, isEmpty);
      expect(output.toString(), isEmpty);
    },
  );

  test('feedback never adds help beside a hidden-instruction prompt', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, input: input.stream),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );
    final feedback = ThemeFeedbackTracer(owner);
    final index = await feedback.spinner('Index');
    final prompt = owner.prompt(
      (handle) => TextInput(
        'Name',
        instructions: InstructionDisplay.hidden,
      ).prompt(session: handle.session),
    );
    index.component.update('reading');
    input.add('Ada\r');
    await input.close();

    expect((await prompt as Accepted<String>).value, 'Ada');
    await index.finish(FeedbackOutcome.completed);
    final text = output.toString();
    expect(
      RegExp(r'Enter submits; /help opens help').allMatches(text),
      hasLength(1),
    );
    expect(text, contains('- Index: reading'));
    expect(text, contains('+ Success: Index: completed'));
  });

  test('screen-reader guidance precedes a prompt with live feedback', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, input: input.stream),
      interaction: const InteractionPreferences(
        mode: PromptMode.linear,
        screenReader: ScreenReaderPreference.on,
      ),
    );
    final presentation = composePromptPresentation(
      mode: PresentationMode.screenReader,
      prompt: 'Name',
      essential: 'Name entry.',
      hint: compactHint(
        mode: PresentationMode.screenReader,
        component: ComponentRoute.standard,
        primaryAction: 'Enter submits',
        shortPrimaryAction: 'Enter',
      ),
    );
    final prompt = owner.prompt((handle) async {
      handle.session.presentText(presentation.essentialBefore!);
      return await TextInput(
        'Name',
        instructions: InstructionDisplay.hidden,
      ).prompt(session: handle.session);
    });
    await _pump();
    final index = await ThemeFeedbackTracer(owner).spinner('Index');
    input.add('Ada\r');
    await input.close();

    expect((await prompt as Accepted<String>).value, 'Ada');
    await index.finish(FeedbackOutcome.completed);
    final text = output.toString();
    expect(text, startsWith('Name entry.'));
    expect(text, contains('Success: Index: completed'));
    expect(text, isNot(contains('✓')));
  });

  test('ending a prompt leaves coordinated feedback active', () async {
    final input = StreamController<String>();
    final events = <String>[];
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(output, events: events, input: input.stream),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );
    final feedback = ThemeFeedbackTracer(owner);
    final index = await feedback.spinner('Index');
    final upload = await feedback.progress('Upload', total: 2);
    final tasks = await feedback.multiSpinner(const ['build']);
    final prompt = owner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );
    input.add('Ada\r');
    await input.close();

    expect((await prompt as Accepted<String>).value, 'Ada');
    expect(events, isNot(contains('restore:1')));
    expect(owner.resolvedInteraction, isNotNull);
    await index.finish(FeedbackOutcome.completed);
    await upload.finish(FeedbackOutcome.failed, detail: 'offline');
    expect(events, isNot(contains('restore:1')));
    await tasks.stop();
    expect(events.last, 'restore:1');
    expect(owner.resolvedInteraction, isNull);
    expect(output.toString(), contains('+ Success: Index: completed'));
    expect(output.toString(), contains('x Error: Upload: failed: offline'));
  });

  test(
    'modal help keeps live feedback visible and the prompt draft intact',
    () async {
      final input = StreamController<String>();
      final output = StringBuffer();
      final owner = ThemeSession(
        environment: _environment(
          output,
          input: input.stream,
          profile: _richProfile(columns: 60, rows: 8, alternateScreen: true),
          supportsRich: true,
        ),
        interaction: const InteractionPreferences(mode: PromptMode.rich),
        colors: const ColorPreferences(allowBackgroundQuery: false),
      );
      final index = await ThemeFeedbackTracer(owner).spinner('Index');
      final prompt = owner.prompt(
        (handle) => TextInput('Project').prompt(session: handle.session),
      );
      input.add('de\x1bOP');
      await _pump();
      index.component.update('reading cache');
      input.add('\x1bmo\r');
      await input.close();

      expect((await prompt as Accepted<String>).value, 'demo');
      await index.finish(FeedbackOutcome.completed);
      final text = output.toString();
      expect(text, contains('\x1b[?1049h'));
      expect(text, contains('\x1b[?1049l'));
      expect(text, contains('[status] - Index: reading cache'));
      expect(text, contains('F1 opens help.'));
      expect(
        text.indexOf('F1 opens help.'),
        greaterThan(text.indexOf('Project')),
        reason: 'the rich compact hint stays at the bottom of the prompt area',
      );
      expect(
        text.indexOf('\x1b[?1049l'),
        lessThan(text.lastIndexOf('Index: completed')),
      );
    },
  );

  test('short screens compact live feedback but keep final failures', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final owner = ThemeSession(
      environment: _environment(
        output,
        input: input.stream,
        profile: _richProfile(columns: 40, rows: 1),
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(allowBackgroundQuery: false),
    );
    final feedback = ThemeFeedbackTracer(owner);
    final index = await feedback.spinner('Index');
    final upload = await feedback.progress('Upload', total: 10);
    final prompt = owner.prompt(
      (handle) => TextInput('Project').prompt(session: handle.session),
    );
    index.component.update('reading cache');
    upload.component.update(1);
    input.add('demo\r');
    await input.close();
    await prompt;
    await index.finish(FeedbackOutcome.failed, detail: 'offline');
    await upload.finish(FeedbackOutcome.completed);

    final text = output.toString();
    expect(text, contains('[status] Feedback (2)'));
    expect(text, contains('[status] x Error: Index: failed: offline'));
    expect(text, contains('[status] + Success: Upload: completed'));
  });

  test('a failed writer reaches the caller after restoration', () async {
    final events = <String>[];
    final sink = _FailingSink();
    final owner = ThemeSession(
      environment: _environment(sink, events: events),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    await expectLater(
      ThemeFeedbackTracer(owner).text('Unreachable'),
      throwsA(same(sink.failure)),
    );
    expect(events, ['acquire:1', 'restore:1']);
    expect(owner.resolvedInteraction, isNull);
  });

  test('a primary feedback failure survives a restoration failure', () async {
    final cleanup = StateError('restore failed');
    final sink = _FailingSink();
    final owner = ThemeSession(
      environment: _environment(sink, restoreError: cleanup),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );

    final failure = await ThemeFeedbackTracer(owner)
        .text('Unreachable')
        .then<Object?>((value) => value, onError: (error, _) => error);
    expect(
      failure,
      isA<TerminalSessionCleanupException>()
          .having(
            (error) => error.operationError,
            'primary',
            same(sink.failure),
          )
          .having((error) => error.cleanupError, 'cleanup', same(cleanup)),
    );
    expect(owner.cleanupFailures, [same(cleanup)]);
  });

  test('caller-owned streams survive coordinated feedback cleanup', () async {
    var cancellations = 0;
    final input = StreamController<String>(onCancel: () => cancellations++);
    input.add('Ada\r');
    final owner = ThemeSession(
      environment: _environment(StringBuffer(), input: input.stream),
      interaction: const InteractionPreferences(mode: PromptMode.linear),
    );
    final index = await ThemeFeedbackTracer(owner).spinner('Index');
    final answer = await owner.prompt(
      (handle) => TextInput('Name').prompt(session: handle.session),
    );
    await index.stop();

    expect((answer as Accepted<String>).value, 'Ada');
    expect(input.isClosed, isFalse);
    expect(cancellations, greaterThan(0));
    await input.close();
  });

  test('non-success outcomes keep distinct textual labels', () async {
    for (final outcome in [
      FeedbackOutcome.cancelled,
      FeedbackOutcome.interrupted,
      FeedbackOutcome.skipped,
    ]) {
      final output = StringBuffer();
      final owner = ThemeSession(
        environment: _environment(output),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
      );
      final index = await ThemeFeedbackTracer(owner).spinner('Index');
      await index.finish(outcome, detail: 'request');

      expect(
        output.toString(),
        '/ Index: running\n'
        '! Warning: Index: ${outcome.name}: request\n',
      );
    }
  });

  test(
    'a component colour override layers over the resolved theme palette',
    () async {
      final output = StringBuffer();
      final override = TerminalColor.rgb(4, 5, 6);
      final owner = ThemeSession(
        environment: _environment(
          output,
          profile: const OutputProfile(
            glyphs: GlyphSet.ascii,
            colorDepth: ColorDepth.rgb,
          ),
        ),
        interaction: const InteractionPreferences(mode: PromptMode.linear),
        colors: ColorPreferences(
          allowBackgroundQuery: false,
          colors: ComponentColors(
            roles: ColorRoleOverrides(success: TerminalColor.rgb(1, 2, 3)),
          ),
        ),
      );
      final feedback = ThemeFeedbackTracer(
        owner,
        colors: ComponentColors(
          roles: ColorRoleOverrides(success: TerminalColor.rgb(4, 5, 6)),
        ),
      );

      await feedback.text('Layered', kind: TextKind.success);

      expect(
        output.toString(),
        contains(
          terminalSgr(override, background: false, depth: ColorDepth.rgb),
        ),
      );
      expect(output.toString(), contains('+ Success: Layered'));
    },
  );
}

Future<void> _pump([int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _FailingSink implements StringSink {
  final Object failure = StateError('writer failed');

  @override
  void write(Object? object) {
    if (object.toString().contains('Unreachable')) {
      Error.throwWithStackTrace(failure, StackTrace.empty);
    }
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    for (final object in objects) {
      write(object);
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => write(object);
}

OutputProfile _richProfile({
  required int columns,
  required int rows,
  bool alternateScreen = false,
}) => OutputProfile(
  cursor: CapabilitySupport.supported,
  alternateScreen: alternateScreen
      ? CapabilitySupport.supported
      : CapabilitySupport.unsupported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  glyphs: GlyphSet.ascii,
  geometry: OutputGeometry.fixed(columns: columns, rows: rows),
);

final class _FakeFeedbackClock implements FeedbackClock {
  Duration _elapsed = Duration.zero;
  final List<_FakeFeedbackTimer> timers = [];

  @override
  Duration get elapsed => _elapsed;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) {
    final timer = _FakeFeedbackTimer(callback);
    timers.add(timer);
    return timer;
  }

  void elapse(Duration duration) {
    _elapsed += duration;
    for (final timer in timers) {
      if (!timer.cancelled) timer.callback();
    }
  }
}

final class _FakeFeedbackTimer implements FeedbackTimer {
  _FakeFeedbackTimer(this.callback);

  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

TerminalEnvironment _environment(
  StringSink output, {
  OutputProfile profile = const OutputProfile(glyphs: GlyphSet.ascii),
  Stream<String>? input,
  List<String>? events,
  Object? ownershipIdentity,
  Object? restoreError,
  Map<String, String?> environment = const <String, String?>{},
  bool supportsRich = false,
}) => TerminalEnvironment.custom(
  adapter: _RecordingTerminal(
    input ?? const Stream<String>.empty(),
    output,
    events ?? <String>[],
    restoreError: restoreError,
    environment: environment,
  ),
  profile: profile,
  supportsRich: supportsRich,
  ownershipIdentity: ownershipIdentity,
);

final class _RecordingTerminal implements TerminalIo {
  _RecordingTerminal(
    this.input,
    this.output,
    this.events, {
    this.restoreError,
    this.environment = const <String, String?>{},
  });

  @override
  final Stream<String> input;
  @override
  final StringSink output;
  final List<String> events;
  final Object? restoreError;
  @override
  final Map<String, String?> environment;
  var _acquired = 0;

  @override
  bool get supportsRich => false;

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
