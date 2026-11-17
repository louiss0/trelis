import 'package:trelis/trelis.dart';

Future<void> main(List<String> args) async {
  if (args.first == 'resolve') {
    final result = await NumberInput(
      'Number',
      decimal: true,
    ).prompt(source: SuppliedAnswer(args[1]));
    print(
      result is Accepted<NumericAnswer?>
          ? '${result.value?.coefficient}:${result.value?.scale}'
          : 'failure',
    );
    return;
  }
  final system = args.first == 'system-rich' || args.first == 'system-linear';
  final mode = args.first.endsWith('linear')
      ? PromptMode.linear
      : PromptMode.rich;
  final result = await NumberInput(
    'Number',
    convention: system ? null : NumericConvention.ascii(),
    decimal: system,
  ).prompt(mode: mode);
  print(
    result is Accepted<NumericAnswer?> ? result.value?.spelling : 'failure',
  );
}
