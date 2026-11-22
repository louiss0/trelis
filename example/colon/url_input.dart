import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// URLInput — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.forestFloor).
///
/// Run: dart run example/colon/url_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'https://example.com/\r',
  (io) => ColonTheme(io: io).urlInput(
    'URL',
    allowedSchemes: {'https'},
    colors: ComponentColors.palette(ColorThemes.forestFloor),
  ),
);
