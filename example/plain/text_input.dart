import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TextInput — one component, one structural theme (PlainTheme),
/// one colour theme (ColorThemes.signal).
///
/// Run: dart run example/plain/text_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ada\r',
  (io) => PlainTheme(io: io).textInput(
    'Deployment target',
    colors: ComponentColors.palette(ColorThemes.signal),
  ),
);
