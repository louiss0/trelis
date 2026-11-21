import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final mode = args.first == 'linear' ? PromptMode.linear : PromptMode.rich;
  final result = args[1] == 'url'
      ? await URLInput('URL', allowedSchemes: {'https'}).prompt(mode: mode)
      : await EmailInput('Email').prompt(mode: mode);
  print(result is Accepted<String> ? result.value : 'failure');
}
