import 'package:trelis/src/testing/compat_api.dart';

Future<void> main() async {
  final results = <String>[];
  for (var i = 0; i < 2; i++) {
    final result = await Password('Password').prompt(mode: PromptMode.linear);
    results.add(
      result is Accepted<String> && result.value == 'disposable'
          ? 'accepted'
          : 'failed',
    );
  }
  print(results.join(','));
}
