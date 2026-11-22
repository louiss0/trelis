import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// ColorInput — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.blueprint).
///
/// Run: dart run example/round/color_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r',
  (io) => RoundTheme(io: io).colorInput(
    'Colour',
    initialValue: '#fff',
    colors: ComponentColors.palette(ColorThemes.blueprint),
  ),
);
