import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final mode = args.first == 'linear' ? PromptMode.linear : PromptMode.rich;
  if (args[1] == 'ip') {
    final result = await IPAddressInput(
      'Address',
      cidr: true,
      scoped: true,
    ).prompt(mode: mode);
    print(
      result is Accepted<IPAddressValue> ? result.value.spelling : 'failure',
    );
  } else {
    final result = await PortInput('Port').prompt(mode: mode);
    print(result is Accepted<int> ? result.value : 'failure');
  }
}
