import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Checkbox — one component, one structural theme (MinimalTheme),
/// one colour theme (ColorThemes.mainframe).
///
/// Run: dart run example/minimal/checkbox.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) => MinimalTheme(
    io: io,
  ).checkbox('Terms', colors: ComponentColors.palette(ColorThemes.mainframe)),
);
