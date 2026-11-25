import 'dart:io';

import 'package:trelis/src/testing/compat_api.dart';
import 'package:test/test.dart';

void main() {
  test(
    'resolved Windows instructions disclose native pattern and adaptation',
    () async {
      final out = StringBuffer();
      final result = await DateInput('Date').prompt(
        mode: PromptMode.linear,
        source: ScriptedInput(const Stream.empty(), out),
      );
      // The host system date pattern is a declared prerequisite: when it
      // cannot resolve, the test fails as a prerequisite diagnostic instead
      // of passing without evidence.
      if (result is Unavailable<CivilDate>) {
        fail('locale prerequisite missing: system date pattern unavailable');
      }
      expect(out.toString(), contains('effective system pattern'));
      expect(out.toString(), contains('adapted to slash'));
    },
    skip: Platform.isWindows ? false : 'requires a Windows host',
  );
}
