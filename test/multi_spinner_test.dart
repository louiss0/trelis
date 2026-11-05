import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('group retains each outcome in task order', () {
    final out = StringBuffer();
    final group = MultiSpinner(['build', 'test']);
    group.start(output: out);
    group.finishTask('test', FeedbackOutcome.failed, detail: 'broken');
    group.finishTask('build', FeedbackOutcome.completed);
    expect(
      out.toString(),
      contains('Summary:\nbuild: completed\ntest: failed: broken\n'),
    );
  });
  test(
    'group batches latest task states and finalization defeats stale updates',
    () async {
      final out = StringBuffer();
      final group = MultiSpinner([
        'a',
        'b',
      ], interval: const Duration(milliseconds: 50));
      group.start(output: out);
      group.update('a', TaskActivity.running, phase: 'first');
      group.update('a', TaskActivity.running, phase: 'old');
      group.update('b', TaskActivity.waiting, phase: 'disk');
      group.update('a', TaskActivity.running, phase: 'latest');
      group.finishTask('b', FeedbackOutcome.failed, detail: 'bad');
      group.update('b', TaskActivity.running, phase: 'stale');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(out.toString(), contains('a: running, latest'));
      expect(out.toString(), isNot(contains('a: running, old')));
      expect(out.toString(), isNot(contains('b: waiting, disk')));
      expect(out.toString(), isNot(contains('stale')));
      group.finishTask('a', FeedbackOutcome.completed);
      expect(
        out.toString(),
        contains('Summary:\na: completed\nb: failed: bad\n'),
      );
    },
  );
  test('many concurrent tasks share one intermediate batch window', () async {
    final names = List.generate(100, (i) => 'task-$i');
    final out = StringBuffer();
    final group = MultiSpinner(
      names,
      interval: const Duration(milliseconds: 80),
    );
    group.start(output: out);
    group.update(names.first, TaskActivity.running, phase: 'initial');
    final before = out.toString();
    for (final name in names) {
      group.update(name, TaskActivity.running, phase: 'old');
      group.update(name, TaskActivity.running, phase: 'new');
    }
    expect(out.toString(), before);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final lines = out.toString().substring(before.length).trim().split('\n');
    expect(lines.length, 100);
    for (var i = 0; i < names.length; i++) {
      expect(lines[i], '${names[i]}: running, new');
    }
    group.dispose();
  });

  test(
    'rich static state, literal names and mixed summary preserve meaning',
    () {
      final out = StringBuffer();
      final group = MultiSpinner(['one\x1b', 'two']);
      group.start(output: out, mode: PromptMode.rich, supportsRich: true);
      group.update('one\x1b', TaskActivity.running, phase: 'compile\x1b');
      group.finishTask('two', FeedbackOutcome.cancelled);
      group.finishTask('one\x1b', FeedbackOutcome.failed, detail: 'bad\x1b');
      expect(
        out.toString(),
        contains('[status] one\\u001b: running, compile\\u001b'),
      );
      expect(
        out.toString(),
        contains(
          '[status] Summary:\n[status] one\\u001b: failed: bad\\u001b\n[status] two: cancelled\n',
        ),
      );
      expect(out.toString(), isNot(contains('\x1b')));
    },
  );

  test('disposal retains unfinished state without inventing outcomes', () {
    final out = StringBuffer();
    final group = MultiSpinner(['one', 'two']);
    group.start(output: out);
    group.update('one', TaskActivity.running, phase: 'work');
    group.dispose();
    final result = out.toString();
    group.finishTask('one', FeedbackOutcome.completed);
    expect(out.toString(), result);
    expect(result, contains('Summary:\none: running, work\ntwo: waiting\n'));
    expect(result, isNot(contains('completed')));
  });

  test(
    'invalid task configuration and unavailable rich mode fail before output',
    () {
      expect(() => MultiSpinner([]), throwsArgumentError);
      expect(() => MultiSpinner(['a', 'a']), throwsArgumentError);
      expect(() => MultiSpinner(['']), throwsArgumentError);
      expect(
        () => MultiSpinner(['a'], interval: const Duration(seconds: -1)),
        throwsArgumentError,
      );
      final out = StringBuffer();
      final group = MultiSpinner(['a']);
      expect(
        () => group.start(
          output: out,
          mode: PromptMode.rich,
          supportsRich: false,
        ),
        throwsStateError,
      );
      expect(out.toString(), isEmpty);
      group.start(
        output: out,
        userPreference: PromptMode.linear,
        applicationPreference: PromptMode.rich,
        supportsRich: true,
      );
      expect(
        () => group.update('unknown', TaskActivity.running),
        throwsArgumentError,
      );
      expect(out.toString(), 'a: waiting\n');
      group.dispose();
    },
  );
}
