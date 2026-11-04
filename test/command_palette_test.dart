import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test(
    'accepts a command identity without executing application work',
    () async {
      var executions = 0;
      final actions = <String, void Function()>{'save': () => executions++};
      final out = StringBuffer();
      final result = await CommandPalette('Commands', [Choice('save', 'Save')])
          .prompt(
            source: ScriptedInput(Stream.value('sav\r\r'), out),
            mode: PromptMode.rich,
          );
      expect((result as Accepted<String>).value, 'save');
      expect(executions, 0);
      actions[result.value]!();
      expect(executions, 1);
      expect(out.toString(), contains('CommandPalette'));
    },
  );
}
