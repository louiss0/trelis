import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// CommandPalette — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.ember).
///
/// Run: dart run example/double/command_palette.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'sav\r1\r',
  (io) => DoubleTheme(io: io).commandPalette<String>('Commands', [
    Choice('save', 'Save'),
  ], colors: ComponentColors.palette(ColorThemes.ember)),
);
