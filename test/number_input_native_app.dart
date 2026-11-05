import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final mode = args.first == 'linear' ? PromptMode.linear : PromptMode.rich;
  final result = await NumberInput(
    'Number',
    convention: NumericConvention.ascii(),
  ).prompt(mode: mode);
  print(
    result is Accepted<NumericAnswer?> ? result.value?.spelling : 'failure',
  );
}
