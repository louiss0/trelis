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
}
