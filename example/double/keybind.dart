import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Keybind — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.ledger).
///
/// Run: dart run example/double/keybind.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ctrl+B+C\r',
  (io) => DoubleTheme(io: io)
      .keybind('Shortcut', colors: ComponentColors.palette(ColorThemes.ledger)),
);
