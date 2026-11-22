import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Confirm — one component, one structural theme (PlainTheme),
/// one colour theme (ColorThemes.orchid).
///
/// Run: dart run example/plain/confirm.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) => PlainTheme(io: io)
      .confirm('Decision', colors: ComponentColors.palette(ColorThemes.orchid)),
);
