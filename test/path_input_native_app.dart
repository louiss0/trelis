import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final result = await PathInput(
    'Path',
    initialValue: 'draft',
    allowNonexistent: true,
  ).prompt(mode: args.first == 'linear' ? PromptMode.linear : PromptMode.rich);
  if (result is Accepted<String>) {
    print(result.value);
  } else {
    print('failure');
  }
}
