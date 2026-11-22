import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// ColorInput — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.blueprint).
///
/// Run: dart run example/bracket/color_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r',
  (io) => BracketTheme(io: io).colorInput(
    'Colour',
    initialValue: '#fff',
    colors: ComponentColors.palette(ColorThemes.blueprint),
  ),
);
