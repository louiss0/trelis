import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Multiline — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.basalt).
///
/// Run: dart run example/branch/multiline.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'abc\r/done\r',
  (io) => BranchTheme(io: io)
      .multiline('Notes', colors: ComponentColors.palette(ColorThemes.basalt)),
);
