import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// PortInput — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.terminalAmber).
///
/// Run: dart run example/branch/port_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '99999\r\x7f\x7f\x7f\x7f\x7f443\r',
  (io) => BranchTheme(io: io).portInput(
    'Port',
    colors: ComponentColors.palette(ColorThemes.terminalAmber),
  ),
);
