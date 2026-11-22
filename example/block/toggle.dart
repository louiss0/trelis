import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Toggle — one component, one structural theme (BlockTheme),
/// one colour theme (ColorThemes.clay).
///
/// Run: dart run example/block/toggle.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) =>
      BlockTheme(io: io)
          .toggle('Cache', colors: ComponentColors.palette(ColorThemes.clay)),
);
