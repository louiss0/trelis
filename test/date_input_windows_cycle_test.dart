import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('Windows Buddhist calendar agrees across a 400-year month cycle', () async {
    if (!Platform.isWindows) return;
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      r"$c=[System.Globalization.ThaiBuddhistCalendar]::new(); for($y=2000;$y -lt 2400;$y++){for($m=1;$m -le 12;$m++){foreach($d in @(1,[datetime]::DaysInMonth($y,$m))){$v=[datetime]::new($y,$m,$d); '{0}/{1}/{2}|{3:yyyy-MM-dd}' -f $c.GetDayOfMonth($v),$c.GetMonth($v),$c.GetYear($v),$v}}}",
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final lines = (result.stdout as String).trim().split(RegExp(r'\r?\n'));
    expect(lines, hasLength(9600));
    final input = DateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      calendar: DateCalendar.buddhist,
    );
    for (final line in lines) {
      final parts = line.split('|');
      final answer = await input.prompt(source: SuppliedAnswer(parts[0]));
      expect(answer, isA<Accepted<CivilDate>>(), reason: line);
      final value = (answer as Accepted<CivilDate>).value;
      final actual =
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      expect(actual, parts[1], reason: line);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
