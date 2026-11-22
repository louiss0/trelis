import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// KeyChordInput — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.ledger).
///
/// Run: dart run example/ledger/key_chord_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/capture\ra/capture\rb/done\r',
  (io) => LedgerTheme(io: io).keyChordInput(
    'Sequence',
    colors: ComponentColors.palette(ColorThemes.ledger),
  ),
);
