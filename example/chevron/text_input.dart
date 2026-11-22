import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TextInput — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.signal).
///
/// Run: dart run example/chevron/text_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ada\r',
  (io) => ChevronTheme(io: io).textInput(
    'Deployment target',
    colors: ComponentColors.palette(ColorThemes.signal),
  ),
);
