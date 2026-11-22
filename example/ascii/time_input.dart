import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimeInput — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.matcha).
///
/// Run: dart run example/ascii/time_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r',
  (io) => AsciiTheme(io: io).timeInput(
    'Time',
    initialValue: '23:59',
    colors: ComponentColors.palette(ColorThemes.matcha),
  ),
);
