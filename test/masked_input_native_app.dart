import 'package:trelis/src/testing/compat_api.dart';

Future<void> main(List<String> args) async {
  final mode = args[0] == 'linear' ? PromptMode.linear : PromptMode.rich;
  final adaptive = args.length > 1 && args[1].startsWith('adaptive');
  bool digit(String value) => '0123456789'.contains(value);
  final result = await MaskedInput(
    'Code',
    templates: [
      if (adaptive)
        MaskTemplate('pair', [
          MaskSlot('digit', digit),
          MaskSlot('digit', digit),
        ]),
      MaskTemplate('code', [
        MaskSlot('digit', digit),
        MaskLiteral('-'),
        MaskSlot('digit', digit),
      ]),
    ],
  ).prompt(mode: mode);
  print(result is Accepted<MaskedValue> ? result.value.formatted : 'failure');
}
