import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Toggle — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.clay).
///
/// Run: dart run example/bracket/toggle.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) =>
      BracketTheme(io: io)
          .toggle('Cache', colors: ComponentColors.palette(ColorThemes.clay)),
);
