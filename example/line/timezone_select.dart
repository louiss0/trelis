import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimezoneSelect — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.obsidian).
///
/// Run: dart run example/line/timezone_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'US/Eastern\r105\r',
  (io) => LineTheme(io: io).timezoneSelect(
    'Zone',
    colors: ComponentColors.palette(ColorThemes.obsidian),
  ),
);
