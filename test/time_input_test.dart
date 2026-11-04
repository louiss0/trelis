import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('linear time entry accepts a time of day without date or zone', () async {
    final result = await TimeInput('Time').prompt(
      source: SuppliedAnswer('23:59'),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<({int hour, int minute, int? second})>).value,
        (hour: 23, minute: 59, second: null));
  });
}
