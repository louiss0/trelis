import 'package:prompty/prompty.dart';

Future<void> main() async {
  final result = await TimeInput(
    'Time',
    initialValue: '12:34',
  ).prompt(mode: PromptMode.rich);
  if (result is Accepted<({int hour, int minute, int? second})>) {
    print('${result.value.hour}:${result.value.minute}');
  } else {
    print('failure');
  }
}
