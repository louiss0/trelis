import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

import 'support/fake_feedback_clock.dart';

void main() {
  test('Text presents literal safe semantic content', () {
    final output = StringBuffer();
    Text('Careful\x1b[31m!', kind: TextKind.warning).present(output: output);
    expect(output.toString(), 'Warning: Careful\\u001b[31m!\n');
  });
  test(
    'linear progress preserves explicit outcomes and rejects invalid updates',
    () {
      final out = StringBuffer();
      final progress = Progress('Download', total: 10);
      progress.start(output: out);
      progress.update(5);
      expect(() => progress.update(11), throwsArgumentError);
      progress.finish(FeedbackOutcome.failed, detail: 'network');
      progress.update(9);
      expect(out.toString(), contains('Download: running, 0%'));
      expect(out.toString(), contains('Download: running, 50%'));
      expect(out.toString(), contains('Download: failed: network'));
      expect(out.toString(), isNot(contains('90%')));
    },
  );
  test('linear progress coalesces milestones and finalization cancels pending updates', () {
    final out = StringBuffer();
    final clock = FakeFeedbackClock();
    final progress = Progress(
      'Work',
      total: 100,
      interval: const Duration(seconds: 5),
      clock: clock,
    );
    progress.start(output: out);
    progress.update(5);
    progress.update(10);
    progress.update(20);
    progress.update(35);
    expect(out.toString(), 'Work: running, 0%\nWork: running, 10%\n');
    clock.elapse(const Duration(seconds: 5));
    expect(
      out.toString(),
      'Work: running, 0%\nWork: running, 10%\nWork: running, 35%\n',
    );
    final pending = Progress(
      'Pending',
      total: 100,
      interval: const Duration(seconds: 2),
      clock: clock,
    );
    pending.start(output: out);
    pending.update(10);
    pending.update(50);
    pending.finish(FeedbackOutcome.completed);
    clock.elapse(const Duration(seconds: 5));
    expect(out.toString(), endsWith('Pending: completed\n'));
    expect(out.toString(), isNot(contains('Pending: running, 50%')));
  });
  test(
    'indeterminate progress reports phase and changed totals explicitly',
    () {
      final out = StringBuffer();
      final progress = Progress('Build');
      progress.start(output: out);
      progress.phase('Compiling');
      progress.setTotal(20, completed: 5);
      progress.setTotal(40, completed: 5);
      progress.finish(FeedbackOutcome.interrupted);
      expect(out.toString(), contains('Build: running, indeterminate'));
      expect(out.toString(), contains('Build: running, Compiling'));
      expect(out.toString(), contains('Build: recalculated, 25%'));
      expect(out.toString(), contains('Build: recalculated, 12%'));
      expect(out.toString(), contains('Build: interrupted'));
    },
  );
  test('progress run reports through the work callback and finishes', () async {
    final out = StringBuffer();
    final progress = Progress('Build', total: 3, interval: Duration.zero);
    progress.start(output: out);
    final value = await progress.run((report) async {
      report(1);
      report(2);
      report(3);
      return 'artifact';
    }, detail: '3 items');
    expect(value, 'artifact');
    expect(out.toString(), contains('completed: 3 items'));
  });
  test('progress run finishes failed and rethrows when work throws', () async {
    final out = StringBuffer();
    final progress = Progress('Build', total: 3, interval: Duration.zero);
    progress.start(output: out);
    await expectLater(
      progress.run((report) => Future<int>.error(StateError('nope'))),
      throwsA(isA<StateError>()),
    );
    expect(out.toString(), contains('failed: Bad state: nope'));
  });
  test(
    'progress follow applies streamed counts and finishes on close',
    () async {
      final out = StringBuffer();
      final progress = Progress('Build', total: 3, interval: Duration.zero);
      progress.start(output: out);
      await progress.follow(Stream.fromIterable([1, 2, 3]), detail: '3 items');
      expect(out.toString(), contains('completed: 3 items'));
    },
  );
  test('progress onClosed fires once on finish and not on later dispose', () {
    var calls = 0;
    final progress = Progress('Build', onClosed: () => calls++);
    progress.start(output: StringBuffer());
    progress.finish(FeedbackOutcome.completed);
    progress.dispose();
    expect(calls, 1);
  });
  test('spinner presents actual activity and explicit final state without heartbeat', () {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out);
    spinner.update('waiting for disk');
    spinner.update('waiting for disk');
    spinner.finish(FeedbackOutcome.failed, detail: 'disk error');
    spinner.update('running');
    expect(
      out.toString(),
      '/ Index: running\n- Index: waiting for disk\nx Index: failed: disk error\n',
    );
  });
  test('spinner run finishes with the resolved future', () async {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out);
    final value = await spinner.run(
      () => Future<int>.value(42),
      active: 'querying',
      detail: 'ready',
    );
    expect(value, 42);
    expect(
      out.toString(),
      '/ Index: running\n- Index: querying\n+ Index: completed: ready\n',
    );
  });
  test('spinner run finishes failed and rethrows when work throws', () async {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out);
    await expectLater(
      spinner.run(() => Future<int>.error(StateError('nope'))),
      throwsA(isA<StateError>()),
    );
    expect(
      out.toString(),
      '/ Index: running\nx Index: failed: Bad state: nope\n',
    );
  });
  test('spinner follow shows streamed labels and finishes on close', () async {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out);
    await spinner.follow(
      Stream.fromIterable(['reading', 'writing']),
      detail: 'done',
    );
    expect(
      out.toString(),
      '/ Index: running\n- Index: reading\n\\ Index: writing\n+ Index: completed: done\n',
    );
  });
  test('spinner follow finishes failed and rethrows on stream error', () async {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out);
    await expectLater(
      spinner.follow(Stream<String>.error(StateError('lost'))),
      throwsA(isA<StateError>()),
    );
    expect(
      out.toString(),
      '/ Index: running\nx Index: failed: Bad state: lost\n',
    );
  });
  test('spinner onClosed fires once on finish and not on later dispose', () {
    var calls = 0;
    final spinner = Spinner('Index', onClosed: () => calls++);
    spinner.start(output: StringBuffer());
    spinner.finish(FeedbackOutcome.completed);
    spinner.dispose();
    expect(calls, 1);
  });
  test('rich spinner advances its frame glyph and drops the status tag', () {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out, mode: PromptMode.rich, supportsRich: true);
    spinner.update('waiting');
    spinner.finish(FeedbackOutcome.skipped);
    expect(
      out.toString(),
      '/ Index: running\n- Index: waiting\n! Index: skipped\n',
    );
  });
  test(
    'rich progress updates actual values and disposal does not imply success',
    () {
      final out = StringBuffer();
      final progress = Progress('Build', total: 100);
      progress.start(output: out, mode: PromptMode.rich, supportsRich: true);
      progress.update(1);
      progress.dispose();
      progress.update(50);
      expect(out.toString(), contains('1%'));
      expect(out.toString(), isNot(contains('completed')));
      expect(out.toString(), isNot(contains('50%')));
      expect(out.toString(), endsWith('\n'));
    },
  );
  test(
    'rich wrapped states remain intact without cursor-dependent erasure',
    () {
      final out = StringBuffer();
      final spinner = Spinner('A very long task name');
      spinner.start(output: out, mode: PromptMode.rich, supportsRich: true);
      spinner.update('A long wrapped phase');
      spinner.finish(FeedbackOutcome.failed, detail: 'long wrapped failure');
      expect(out.toString(), isNot(contains('\x1b[2K')));
      expect(out.toString(), contains('A long wrapped phase'));
      expect(out.toString(), contains('failed: long wrapped failure'));
    },
  );
  test('coalescing never emits an unchanged numeric heartbeat', () {
    final out = StringBuffer();
    final clock = FakeFeedbackClock();
    final progress = Progress(
      'Task',
      total: 100,
      interval: const Duration(seconds: 5),
      clock: clock,
    );
    progress.start(output: out);
    progress.update(10);
    progress.update(20);
    progress.update(10);
    clock.elapse(const Duration(seconds: 10));
    progress.dispose();
    expect(out.toString(), 'Task: running, 0%\nTask: running, 10%\n');
  });
  test('feedback preference selects rich only when output supports it', () {
    final out = StringBuffer();
    final progress = Progress('Task', total: 100);
    progress.start(
      output: out,
      userPreference: PromptMode.linear,
      applicationPreference: PromptMode.rich,
      supportsRich: true,
    );
    progress.update(1);
    progress.finish(FeedbackOutcome.completed);
    expect(out.toString(), isNot(contains('1%')));
    expect(out.toString(), contains('completed'));
  });
  test('rich spinner marks live frames and outcomes with glyphs', () {
    final out = StringBuffer();
    final spinner = Spinner('Build');
    spinner.start(output: out, mode: PromptMode.rich, supportsRich: true);
    spinner.update('waiting');
    spinner.finish(FeedbackOutcome.cancelled);
    expect(out.toString(), isNotEmpty);
    expect(
      out.toString(),
      '/ Build: running\n- Build: waiting\n! Build: cancelled\n',
    );
  });
  test(
    'every outcome stays final after stale phase, value and total updates',
    () {
      for (final outcome in FeedbackOutcome.values) {
        final out = StringBuffer();
        final progress = Progress('Job', total: 10);
        progress.start(output: out);
        progress.update(10);
        expect(out.toString(), isNot(contains('completed')));
        progress.finish(outcome, detail: 'detail');
        final finalText = out.toString();
        progress.update(1);
        progress.phase('late');
        progress.setTotal(100);
        progress.finish(FeedbackOutcome.completed);
        expect(out.toString(), finalText);
        expect(finalText, contains('${outcome.name}: detail'));
      }
    },
  );
  test('invalid totals retain the previous valid display', () {
    final out = StringBuffer();
    final progress = Progress('Job', total: 10);
    progress.start(output: out);
    expect(() => progress.setTotal(0), throwsArgumentError);
    expect(() => progress.setTotal(10, completed: -1), throwsArgumentError);
    expect(() => progress.setTotal(10, completed: 11), throwsArgumentError);
    expect(() => progress.setTotal(null, completed: 1), throwsArgumentError);
    expect(out.toString(), 'Job: running, 0%\n');
    progress.finish(FeedbackOutcome.interrupted);
  });
  test(
    'rich progress exposes real value changes below percentage precision',
    () {
      final out = StringBuffer();
      final progress = Progress('Job', total: 1000);
      progress.start(output: out, mode: PromptMode.rich, supportsRich: true);
      progress.update(1);
      progress.update(2);
      progress.finish(FeedbackOutcome.completed);
      expect(out.toString(), contains('0% (1/1000)'));
      expect(out.toString(), contains('0% (2/1000)'));
    },
  );

  test(
    'progress cadence is deterministic with an application-controlled clock',
    () {
      final out = StringBuffer();
      final clock = FakeFeedbackClock();
      final progress = Progress(
        'Upload',
        total: 100,
        interval: const Duration(seconds: 5),
        clock: clock,
      );

      progress.start(output: out);
      progress.update(10);
      progress.update(20);
      expect(out.toString(), isNot(contains('20%')));

      clock.elapse(const Duration(seconds: 5));
      expect(out.toString(), contains('Upload: running, 20%'));
      progress.dispose();
    },
  );

  test(
    'multi-spinner run finishes each task when its own future resolves',
    () async {
      final out = StringBuffer();
      final tasks = MultiSpinner(['fetch', 'parse'], interval: Duration.zero);
      tasks.start(output: out);
      final values = await Future.wait([
        tasks.run('fetch', () => Future<int>.value(1), detail: 'done'),
        tasks.run('parse', () => Future<int>.value(2)),
      ]);
      expect(values, [1, 2]);
      final text = out.toString();
      expect(text, contains('fetch: running'));
      expect(text, contains('parse: running'));
      expect(text, contains('fetch: completed: done'));
      expect(text, contains('parse: completed'));
    },
  );
  test('multi-spinner run finishes a task failed and rethrows', () async {
    final out = StringBuffer();
    final tasks = MultiSpinner(['fetch', 'parse'], interval: Duration.zero);
    tasks.start(output: out);
    await expectLater(
      Future.wait([
        tasks.run('fetch', () => Future<int>.error(StateError('lost'))),
        tasks.run('parse', () => Future<int>.value(2)),
      ]),
      throwsA(isA<StateError>()),
    );
    expect(out.toString(), contains('fetch: failed: Bad state: lost'));
    expect(out.toString(), contains('parse: completed'));
  });
  test('multi-spinner runAll returns results and settles every task', () async {
    final out = StringBuffer();
    final tasks = MultiSpinner(['fetch', 'parse'], interval: Duration.zero);
    tasks.start(output: out);
    final results = await tasks.runAll({
      'fetch': () => Future<int>.value(1),
      'parse': () => Future<int>.value(2),
    });
    expect(results, {'fetch': 1, 'parse': 2});
    expect(out.toString(), contains('fetch: completed'));
    expect(out.toString(), contains('parse: completed'));
  });
  test('multi-spinner runAll settles siblings before rethrowing', () async {
    final out = StringBuffer();
    final tasks = MultiSpinner(['fetch', 'parse'], interval: Duration.zero);
    tasks.start(output: out);
    await expectLater(
      tasks.runAll({
        'fetch': () => Future<int>.error(StateError('lost')),
        'parse': () => Future<int>.value(2),
      }),
      throwsA(isA<StateError>()),
    );
    expect(out.toString(), contains('fetch: failed: Bad state: lost'));
    expect(out.toString(), contains('parse: completed'));
  });
  test('multi-spinner follow streams phases and finishes on close', () async {
    final out = StringBuffer();
    final tasks = MultiSpinner(['fetch'], interval: Duration.zero);
    tasks.start(output: out);
    await tasks.follow('fetch', Stream.fromIterable(['chunk 1', 'chunk 2']));
    final text = out.toString();
    expect(text, contains('fetch: running, chunk 1'));
    expect(text, contains('fetch: running, chunk 2'));
    expect(text, contains('fetch: completed'));
  });
  test(
    'multi-spinner followAll settles each task and errors rethrow',
    () async {
      final out = StringBuffer();
      final tasks = MultiSpinner(['fetch', 'parse'], interval: Duration.zero);
      tasks.start(output: out);
      await expectLater(
        tasks.followAll({
          'fetch': Stream<String>.error(StateError('lost')),
          'parse': Stream.fromIterable(['token']),
        }),
        throwsA(isA<StateError>()),
      );
      expect(out.toString(), contains('fetch: failed: Bad state: lost'));
      expect(out.toString(), contains('parse: completed'));
    },
  );
  test('multi-spinner onClosed fires when the last task finishes', () {
    var calls = 0;
    final tasks = MultiSpinner(['a', 'b'], onClosed: () => calls++);
    tasks.start(output: StringBuffer());
    tasks.finishTask('a', FeedbackOutcome.completed);
    expect(calls, 0);
    tasks.finishTask('b', FeedbackOutcome.completed);
    expect(calls, 1);
  });
  test('multi-spinner batching is deterministic with an application-controlled clock', () {
    final out = StringBuffer();
    final clock = FakeFeedbackClock();
    final tasks = MultiSpinner(
      ['compile'],
      interval: const Duration(seconds: 5),
      clock: clock,
    );

    tasks.start(output: out);
    tasks.update('compile', TaskActivity.running, phase: 'first');
    tasks.update('compile', TaskActivity.running, phase: 'latest');
    expect(out.toString(), isNot(contains('latest')));

    clock.elapse(const Duration(seconds: 5));
    expect(out.toString(), contains('compile: running, latest'));
    tasks.dispose();
  });
}
