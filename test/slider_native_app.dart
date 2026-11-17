import 'package:trelis/trelis.dart';

Future<void> main(List<String> args) async {
  if (args.first == 'slider') {
    final result = await Slider(
      'Level',
      minimum: '0',
      maximum: '10',
      step: '1',
      initialValue: '2',
    ).prompt(mode: PromptMode.rich);
    print(result is Accepted<String> ? result.value : 'failure');
  } else {
    final result = await RangeSlider(
      'Range',
      minimum: '0',
      maximum: '10',
      step: '1',
      initialLower: '2',
      initialUpper: '5',
    ).prompt(mode: PromptMode.rich);
    print(
      result is Accepted<(String, String)>
          ? '${result.value.$1},${result.value.$2}'
          : 'failure',
    );
  }
}
