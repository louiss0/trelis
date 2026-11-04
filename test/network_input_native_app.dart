import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final result = await PortInput(
    'Port',
  ).prompt(mode: args.first == 'linear' ? PromptMode.linear : PromptMode.rich);
  print(result is Accepted<int> ? result.value : 'failure');
}
