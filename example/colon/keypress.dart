import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Keypress — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.infrared).
///
/// Run: dart run example/colon/keypress.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/capture\ra/done\r',
  (io) => ColonTheme(
    io: io,
  ).keypress('Shortcut', colors: ComponentColors.palette(ColorThemes.infrared)),
);
