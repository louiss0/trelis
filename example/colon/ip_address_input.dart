import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// IPAddressInput — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.punch).
///
/// Run: dart run example/colon/ip_address_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '192.0.2.7/24\r',
  (io) => ColonTheme(io: io).ipAddressInput(
    'Address',
    cidr: true,
    colors: ComponentColors.palette(ColorThemes.punch),
  ),
);
