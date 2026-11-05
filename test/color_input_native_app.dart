import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final mode = args.first == 'linear' ? PromptMode.linear : PromptMode.rich;
  final result = await ColorInput('Color').prompt(mode: mode);
  print(result is Accepted<ColorValue?> ? result.value?.source : 'failure');
}
