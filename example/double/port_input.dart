import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// PortInput — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.terminalAmber).
///
/// Run: dart run example/double/port_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
  (io) => DoubleTheme(io: io).portInput(
    'Port',
    colors: ComponentColors.palette(ColorThemes.terminalAmber),
  ),
);
