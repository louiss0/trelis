import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final mode = args[0] == 'linear' ? PromptMode.linear : PromptMode.rich;
  final config = CronPreviewConfig(
    zone: 'Etc/UTC',
    reference: DateTime.utc(2024),
    start: DateTime.utc(2024),
    end: DateTime.utc(2024, 1, 1, 0, 3),
    count: 1,
    budget: 3,
  );
  final result = await CronInput(
    'Schedule',
    profile: CronProfile.unix,
    preview: config,
  ).prompt(mode: mode);
  if (result is Accepted<CronExpression>) {
    print(result.value.expression);
  } else {
    print('failure:${result.runtimeType}');
  }
}
