import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// SearchSelect — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.moss).
///
/// Run: dart run example/colon/search_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r1\r',
  (io) => ColonTheme(io: io).searchSelect<String>('Fruit', [
    Choice('a', 'Apple'),
  ], colors: ComponentColors.palette(ColorThemes.moss)),
);
