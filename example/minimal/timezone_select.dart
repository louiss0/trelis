import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimezoneSelect — one component, one structural theme (MinimalTheme),
/// one colour theme (ColorThemes.obsidian).
///
/// Run: dart run example/minimal/timezone_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'US/Eastern\r105\r',
  (io) => MinimalTheme(io: io).timezoneSelect(
    'Zone',
    colors: ComponentColors.palette(ColorThemes.obsidian),
  ),
);
