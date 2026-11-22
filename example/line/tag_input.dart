import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TagInput — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.sandstone).
///
/// Run: dart run example/line/tag_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'NewTag\r/done\r',
  (io) => LineTheme(io: io)
      .tagInput('Tags', colors: ComponentColors.palette(ColorThemes.sandstone)),
);
