import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Toggle — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.clay).
///
/// Run: dart run example/branch/toggle.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'yes\r',
  (io) =>
      BranchTheme(io: io)
          .toggle('Cache', colors: ComponentColors.palette(ColorThemes.clay)),
);
