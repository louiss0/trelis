import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Select — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.copper).
///
/// Run: dart run example/ascii/select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r',
  (io) => AsciiTheme(io: io).select<String>('Choice', [
    Choice('a', 'First'),
    Choice('b', 'Second'),
  ], colors: ComponentColors.palette(ColorThemes.copper)),
);
