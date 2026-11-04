import 'package:prompty/prompty.dart';

Future<void> main() async {
  try {
    final prompt = TextInput('Name', initialValue: 'alpha');
    final results = <String>[];
    for (var i = 0; i < 2; i++) {
      final result = await prompt.prompt(mode: PromptMode.linear);
      results.add(switch (result) {
        Accepted<String>(:final value) => value,
        Cancelled<String>() => 'cancel',
        Interrupted<String>() => 'interrupt',
        InputEnded<String>() => 'eof',
        Unavailable<String>(:final reason) => 'unavailable:$reason',
      });
    }
    print(results.join(','));
  } catch (error) {
    print('ERROR:$error');
  }
}
