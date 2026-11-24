import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final result = await Keybind<List<String>>(
    'Sequence',
    symbols: const ['A', 'B', 'C'],
  ).prompt(mode: args.first == 'linear' ? PromptMode.linear : PromptMode.rich);
  if (result is Accepted<List<String>>) {
    print(result.value.join(','));
  } else {
    print(result.runtimeType);
  }
}
