import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Password — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.vinyl).
///
/// Run: dart run example/chevron/password.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'secret\rsubmit\r',
  (io) => ChevronTheme(
    io: io,
  ).password('Passphrase', colors: ComponentColors.palette(ColorThemes.vinyl)),
);
