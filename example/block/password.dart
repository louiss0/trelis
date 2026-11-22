import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Password — one component, one structural theme (BlockTheme),
/// one colour theme (ColorThemes.vinyl).
///
/// Run: dart run example/block/password.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'secret\rsubmit\r',
  (io) => BlockTheme(
    io: io,
  ).password('Passphrase', colors: ComponentColors.palette(ColorThemes.vinyl)),
);
