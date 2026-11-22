import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Select — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.copper).
///
/// Run: dart run example/ledger/select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r',
  (io) => LedgerTheme(io: io).select<String>('Choice', [
    Choice('a', 'First'),
    Choice('b', 'Second'),
  ], colors: ComponentColors.palette(ColorThemes.copper)),
);
