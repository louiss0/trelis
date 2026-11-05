import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'resolved Windows instructions disclose native pattern and adaptation',
    () async {
      if (!Platform.isWindows) return;
      final out = StringBuffer();
      final result = await DateInput('Date').prompt(
        mode: PromptMode.linear,
        source: ScriptedInput(const Stream.empty(), out),
      );
      if (result is Unavailable<CivilDate>) return;
      expect(out.toString(), contains('effective system pattern'));
      expect(out.toString(), contains('adapted to slash'));
    },
  );
}
