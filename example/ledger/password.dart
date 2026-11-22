import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Password — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.vinyl).
///
/// Run: dart run example/ledger/password.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'secret\rsubmit\r',
  (io) => LedgerTheme(
    io: io,
  ).password('Passphrase', colors: ComponentColors.palette(ColorThemes.vinyl)),
);
