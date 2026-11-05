import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final cancelling = args[0].endsWith('-cancel');
  final mode = args[0].startsWith('linear')
      ? PromptMode.linear
      : PromptMode.rich;
  final config = CronPreviewConfig(
    zone: 'Etc/UTC',
    reference: DateTime.utc(2024),
    start: DateTime.utc(2024),
    end: cancelling ? DateTime.utc(2030) : DateTime.utc(2024, 1, 1, 0, 3),
    count: 1,
    budget: cancelling ? 100000000 : 3,
  );
  final result = await CronInput(
    'Schedule',
    profile: CronProfile.unix,
    preview: config,
  ).prompt(mode: mode);
  if (result is Accepted<CronExpression>) {
    print(result.value.expression);
  } else if (result is Cancelled<CronExpression>) {
    print('cancelled');
  } else if (result is Interrupted<CronExpression>) {
    print('interrupted');
  } else {
    print('failure:${result.runtimeType}');
  }
}
