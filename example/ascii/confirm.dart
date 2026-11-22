import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Confirm — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.orchid).
///
/// Run: dart run example/ascii/confirm.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) => AsciiTheme(io: io)
      .confirm('Decision', colors: ComponentColors.palette(ColorThemes.orchid)),
);
