import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Multiline — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.basalt).
///
/// Run: dart run example/colon/multiline.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'abc\r/done\r',
  (io) => ColonTheme(io: io)
      .multiline('Notes', colors: ComponentColors.palette(ColorThemes.basalt)),
);
