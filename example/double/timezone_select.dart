import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimezoneSelect — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.obsidian).
///
/// Run: dart run example/double/timezone_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'US/Eastern\r105\r',
  (io) => DoubleTheme(io: io).timezoneSelect(
    'Zone',
    colors: ComponentColors.palette(ColorThemes.obsidian),
  ),
);
