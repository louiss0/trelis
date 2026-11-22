import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// MaskedInput — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.porcelain).
///
/// Run: dart run example/form/masked_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/value\r\x7f3\r/done\r',
  (io) => FormTheme(io: io).maskedInput(
    'Code',
    templates: [
      MaskTemplate('code', [
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
        MaskLiteral('-'),
        MaskSlot('digit', (s) => '0123456789'.contains(s)),
      ]),
    ],
    initialValue: MaskedValue('code', ['1', '2'], '1-2'),
    colors: ComponentColors.palette(ColorThemes.porcelain),
  ),
);
