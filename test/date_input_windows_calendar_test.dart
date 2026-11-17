import 'dart:io';

import 'package:trelis/trelis.dart';
import 'package:test/test.dart';

void main() {
  test('Windows ThaiBuddhistCalendar agrees on modern boundary vectors', () async {
    if (!Platform.isWindows) return;
    final ps = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      r"$c=[System.Globalization.ThaiBuddhistCalendar]::new(); foreach ($s in @('1941-01-01','2000-02-29','2024-02-29','2100-03-01','9456-12-31')) { $d=[datetime]::ParseExact($s,'yyyy-MM-dd',$null); '{0}/{1}/{2}|{3}' -f $c.GetDayOfMonth($d),$c.GetMonth($d),$c.GetYear($d),$s }",
    ]);
    expect(ps.exitCode, 0, reason: ps.stderr.toString());
    final input = DateInput(
      'Date',
      order: DateFieldOrder.dayMonthYear,
      calendar: DateCalendar.buddhist,
    );
    for (final line in (ps.stdout as String).trim().split(RegExp(r'\r?\n'))) {
      final parts = line.split('|');
      final date = (await input.prompt(
        source: SuppliedAnswer(parts[0]),
      ) as Accepted<CivilDate>).value;
      final iso =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      expect(iso, parts[1]);
    }
  });
}
