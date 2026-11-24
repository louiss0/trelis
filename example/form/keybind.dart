import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Keybind — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.ledger).
///
/// Run: dart run example/form/keybind.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ctrl+B+C\r',
  (io) => FormTheme(io: io)
      .keybind('Shortcut', colors: ComponentColors.palette(ColorThemes.ledger)),
);
