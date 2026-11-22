import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// SearchSelect — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.moss).
///
/// Run: dart run example/round/search_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r1\r',
  (io) => RoundTheme(io: io).searchSelect<String>('Fruit', [
    Choice('a', 'Apple'),
  ], colors: ComponentColors.palette(ColorThemes.moss)),
);
