import 'package:prompty/prompty.dart';

Future<void> main(List<String> args) async {
  final mode = args[0] == 'linear' ? PromptMode.linear : PromptMode.rich;
  bool digit(String value) => '0123456789'.contains(value);
  final result = await MaskedInput(
    'Code',
    templates: [
      MaskTemplate('code', [
        MaskSlot('digit', digit),
        MaskLiteral('-'),
        MaskSlot('digit', digit),
      ]),
    ],
  ).prompt(mode: mode);
  print(result is Accepted<MaskedValue> ? result.value.formatted : 'failure');
}
