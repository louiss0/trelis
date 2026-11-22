import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TagInput — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.sandstone).
///
/// Run: dart run example/ascii/tag_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'NewTag\r/done\r',
  (io) => AsciiTheme(io: io)
      .tagInput('Tags', colors: ComponentColors.palette(ColorThemes.sandstone)),
);
