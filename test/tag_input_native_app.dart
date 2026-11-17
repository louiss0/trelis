import 'package:trelis/trelis.dart';

Future<void> main() async {
  final result = await TagInput('Tags').prompt(mode: PromptMode.rich);
  print(result is Accepted<List<String>> ? result.value.join(',') : 'failure');
}
