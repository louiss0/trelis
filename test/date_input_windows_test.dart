import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Windows current supported short-date profile resolves automatically',
    () async {
      final p = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        r"$p=Get-ItemProperty 'HKCU:\Control Panel\International'; Write-Output ($p.sShortDate + '|' + $p.iCalendarType + '|' + $p.sNativeDigits)",
      ]);
      // The short-date profile is a declared locale prerequisite of this
      // test: the en-US runner profile must be present, and its absence is a
      // prerequisite diagnostic rather than a silent pass.
      if (p.exitCode != 0 ||
          (p.stdout as String).trim() != 'M/d/yyyy|1|0123456789') {
        fail(
          'locale prerequisite missing: expected the en-US short-date profile '
          'M/d/yyyy|1|0123456789, got exit ${p.exitCode} with '
          "'${(p.stdout as String).trim()}'",
        );
      }
      final result = await DateInput('Date')
          .prompt(source: SuppliedAnswer('2/29/2024'));
      expect(result, isA<Accepted<CivilDate>>());
      expect((result as Accepted<CivilDate>).value.year, 2024);
    },
    skip: Platform.isWindows ? false : 'requires a Windows host',
  );
}
