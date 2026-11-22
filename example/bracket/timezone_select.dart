import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimezoneSelect — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.obsidian).
///
/// Run: dart run example/bracket/timezone_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'US/Eastern\r105\r',
  (io) => BracketTheme(io: io).timezoneSelect(
    'Zone',
    colors: ComponentColors.palette(ColorThemes.obsidian),
  ),
);
