import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final mode = args[0] == 'linear' ? PromptMode.linear : PromptMode.rich;
  final result = await DateInput(
    'Date',
    order: DateFieldOrder.dayMonthYear,
    calendar: DateCalendar.buddhist,
  ).prompt(mode: mode);
  if (result is Accepted<CivilDate>) {
    final value = result.value;
    print(
      '${value.year}-${value.month}-${value.day}:${value.inputYear}:${value.era}',
    );
  } else {
    print('failure:${result.runtimeType}');
  }
}
