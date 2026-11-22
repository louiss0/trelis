import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// KeyChordInput — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.ledger).
///
/// Run: dart run example/round/key_chord_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/capture\ra/capture\rb/done\r',
  (io) => RoundTheme(io: io).keyChordInput(
    'Sequence',
    colors: ComponentColors.palette(ColorThemes.ledger),
  ),
);
