import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimezoneSelect — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.obsidian).
///
/// Run: dart run example/chevron/timezone_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'US/Eastern\r105\r',
  (io) => ChevronTheme(io: io).timezoneSelect(
    'Zone',
    colors: ComponentColors.palette(ColorThemes.obsidian),
  ),
);
