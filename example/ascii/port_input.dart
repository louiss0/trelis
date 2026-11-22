import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// PortInput — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.terminalAmber).
///
/// Run: dart run example/ascii/port_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
  (io) => AsciiTheme(io: io).portInput(
    'Port',
    colors: ComponentColors.palette(ColorThemes.terminalAmber),
  ),
);
