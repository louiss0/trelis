import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Multiline — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.basalt).
///
/// Run: dart run example/chevron/multiline.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'abc\r/done\r',
  (io) => ChevronTheme(io: io)
      .multiline('Notes', colors: ComponentColors.palette(ColorThemes.basalt)),
);
