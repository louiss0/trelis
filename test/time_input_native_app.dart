import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final result = await TimeInput(
    'Time',
    initialValue: '12:34',
  ).prompt(mode: args.first == 'linear' ? PromptMode.linear : PromptMode.rich);
  if (result is Accepted<({int hour, int minute, int? second})>) {
    print('${result.value.hour}:${result.value.minute}');
  } else {
    print('failure');
  }
}
