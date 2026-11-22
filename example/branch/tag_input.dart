import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TagInput — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.sandstone).
///
/// Run: dart run example/branch/tag_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'NewTag\r/done\r',
  (io) => BranchTheme(io: io)
      .tagInput('Tags', colors: ComponentColors.palette(ColorThemes.sandstone)),
);
