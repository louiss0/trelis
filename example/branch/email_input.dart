import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// EmailInput — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.fieldnotes).
///
/// Run: dart run example/branch/email_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Case@example.com\r',
  (io) => BranchTheme(io: io).emailInput(
    'Email',
    colors: ComponentColors.palette(ColorThemes.fieldnotes),
  ),
);
