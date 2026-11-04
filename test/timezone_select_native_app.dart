import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final result = await TimezoneSelect('Zone').prompt(
    mode: args.firstOrNull == 'linear' ? PromptMode.linear : PromptMode.rich,
  );
  print(switch (result) {
    Accepted<String>(:final value) => value,
    Cancelled<String>() => 'cancel',
    Interrupted<String>() => 'interrupt',
    InputEnded<String>() => 'eof',
    Unavailable<String>(:final reason) => 'unavailable:$reason',
  });
}
