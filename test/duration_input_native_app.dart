import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final mode = args[0] == 'linear' ? PromptMode.linear : PromptMode.rich;
  final durationMode = args[1] == 'calendar'
      ? DurationInputMode.calendarRelative
      : DurationInputMode.elapsed;
  final result = await DurationInput(
    'Duration',
    durationMode: durationMode,
  ).prompt(mode: mode);
  print(result is Accepted<DurationValue> ? result.value.draft : 'failure');
}
