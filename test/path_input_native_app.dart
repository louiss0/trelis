import 'package:prompty/prompty.dart';

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
