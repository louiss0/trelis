import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Keybind — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.ledger).
///
/// Run: dart run example/bracket/keybind.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ctrl+B+C\r',
  (io) => BracketTheme(io: io)
      .keybind('Shortcut', colors: ComponentColors.palette(ColorThemes.ledger)),
);
