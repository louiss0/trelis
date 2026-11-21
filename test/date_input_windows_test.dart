import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Windows current supported short-date profile resolves automatically',
    () async {
      if (!Platform.isWindows) return;
      final p = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        r"$p=Get-ItemProperty 'HKCU:\Control Panel\International'; Write-Output ($p.sShortDate + '|' + $p.iCalendarType + '|' + $p.sNativeDigits)",
      ]);
      if (p.exitCode != 0 ||
          (p.stdout as String).trim() != 'M/d/yyyy|1|0123456789') {
        return;
      }
      final result = await DateInput('Date')
          .prompt(source: SuppliedAnswer('2/29/2024'));
      expect(result, isA<Accepted<CivilDate>>());
      expect((result as Accepted<CivilDate>).value.year, 2024);
    },
  );
}
