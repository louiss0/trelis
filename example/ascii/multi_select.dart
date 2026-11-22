import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// MultiSelect — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.citrus).
///
/// Run: dart run example/ascii/multi_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r1\r/done\r',
  (io) => AsciiTheme(io: io).multiSelect<String>('Choices', [
    Choice('a', 'Alpha'),
    Choice('b', 'Beta'),
  ], colors: ComponentColors.palette(ColorThemes.citrus)),
);
