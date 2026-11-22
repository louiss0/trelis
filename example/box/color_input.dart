import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// ColorInput — one component, one structural theme (BoxTheme),
/// one colour theme (ColorThemes.blueprint).
///
/// Run: dart run example/box/color_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r',
  (io) => BoxTheme(io: io).colorInput(
    'Colour',
    initialValue: '#fff',
    colors: ComponentColors.palette(ColorThemes.blueprint),
  ),
);
