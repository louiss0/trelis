import 'package:prompty/prompty.dart';
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
    progress.update(50);
    progress.finish(FeedbackOutcome.completed);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(out.toString(), endsWith('Work: completed\n'));
    expect(out.toString(), isNot(contains('50%')));
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
}
