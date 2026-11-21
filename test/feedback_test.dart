import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

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
  test('linear progress coalesces milestones and finalization cancels pending updates', () async {
    final out = StringBuffer();
    final progress = Progress(
      'Work',
      total: 100,
      interval: const Duration(milliseconds: 60),
    );
    progress.start(output: out);
    progress.update(5);
    progress.update(10);
    progress.update(20);
    progress.update(35);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(
      out.toString(),
      'Work: running, 0%\nWork: running, 10%\nWork: running, 35%\n',
    );
    final pending = Progress(
      'Pending',
      total: 100,
      interval: const Duration(seconds: 2),
    );
    pending.start(output: out);
    pending.update(10);
    pending.update(50);
    pending.finish(FeedbackOutcome.completed);
    await Future<void>.delayed(const Duration(milliseconds: 90));
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
      'Index: running\nIndex: waiting for disk\nIndex: failed: disk error\n',
    );
  });
  test('nonanimated rich feedback retains static state and layout', () {
    final out = StringBuffer();
    final spinner = Spinner('Index');
    spinner.start(output: out, mode: PromptMode.rich, supportsRich: true);
    spinner.update('waiting');
    spinner.finish(FeedbackOutcome.skipped);
    expect(
      out.toString(),
      '[status] Index: running\n[status] Index: waiting\n[status] Index: skipped\n',
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
  test('coalescing never emits an unchanged numeric heartbeat', () async {
    final out = StringBuffer();
    final progress = Progress(
      'Task',
      total: 100,
      interval: const Duration(milliseconds: 80),
    );
    progress.start(output: out);
    progress.update(10);
    progress.update(20);
    progress.update(10);
    await Future<void>.delayed(const Duration(milliseconds: 160));
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
  test('static rich spinner uses an explicit status layout', () {
    final out = StringBuffer();
    final spinner = Spinner('Build');
    spinner.start(output: out, mode: PromptMode.rich, supportsRich: true);
    spinner.update('waiting');
    spinner.finish(FeedbackOutcome.cancelled);
    expect(out.toString(), isNotEmpty);
    expect(
      out.toString(),
      '[status] Build: running\n[status] Build: waiting\n[status] Build: cancelled\n',
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
      final clock = _FakeFeedbackClock();
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

  test('multi-spinner batching is deterministic with an application-controlled clock', () {
    final out = StringBuffer();
    final clock = _FakeFeedbackClock();
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

final class _FakeFeedbackClock implements FeedbackClock {
  Duration _elapsed = Duration.zero;
  final List<_ScheduledCallback> _callbacks = [];

  @override
  Duration get elapsed => _elapsed;

  @override
  FeedbackTimer schedule(Duration delay, void Function() callback) {
    final scheduled = _ScheduledCallback(_elapsed + delay, callback);
    _callbacks.add(scheduled);
    return scheduled;
  }

  void elapse(Duration duration) {
    _elapsed += duration;
    while (true) {
      final due = _callbacks.where((callback) {
        return !callback.cancelled && callback.when <= _elapsed;
      }).toList();
      if (due.isEmpty) return;
      for (final callback in due) {
        _callbacks.remove(callback);
        callback.callback();
      }
    }
  }
}

final class _ScheduledCallback implements FeedbackTimer {
  _ScheduledCallback(this.when, this.callback);

  final Duration when;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}
