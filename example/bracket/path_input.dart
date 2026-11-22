import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// PathInput — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.botanical).
///
/// Run: dart run example/bracket/path_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r\r',
  (io) => BracketTheme(io: io).pathInput(
    'Path',
    initialValue: 'draft',
    allowNonexistent: true,
    colors: ComponentColors.palette(ColorThemes.botanical),
  ),
);
