import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';

Future<void> main() async {
  final result = await DateInput(
    'Date',
    order: DateFieldOrder.dayMonthYear,
  ).prompt(mode: PromptMode.rich);
  if (result is Unavailable<CivilDate>) {
    stdout.writeln('unavailable');
  } else {
    stderr.writeln('Unexpected result');
    exitCode = 1;
  }
}
