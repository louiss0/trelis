import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Checkbox — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.mainframe).
///
/// Run: dart run example/round/checkbox.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) => RoundTheme(
    io: io,
  ).checkbox('Terms', colors: ComponentColors.palette(ColorThemes.mainframe)),
);
