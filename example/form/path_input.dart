import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// PathInput — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.botanical).
///
/// Run: dart run example/form/path_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r\r',
  (io) => FormTheme(io: io).pathInput(
    'Path',
    initialValue: 'draft',
    allowNonexistent: true,
    colors: ComponentColors.palette(ColorThemes.botanical),
  ),
);
