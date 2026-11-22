import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// SearchSelect — one component, one structural theme (RailTheme),
/// one colour theme (ColorThemes.moss).
///
/// Run: dart run example/rail/search_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r1\r',
  (io) => RailTheme(io: io).searchSelect<String>('Fruit', [
    Choice('a', 'Apple'),
  ], colors: ComponentColors.palette(ColorThemes.moss)),
);
