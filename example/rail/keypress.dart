import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Keypress — one component, one structural theme (RailTheme),
/// one colour theme (ColorThemes.infrared).
///
/// Run: dart run example/rail/keypress.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/capture\ra/done\r',
  (io) => RailTheme(
    io: io,
  ).keypress('Shortcut', colors: ComponentColors.palette(ColorThemes.infrared)),
);
