import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// EmailInput — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.fieldnotes).
///
/// Run: dart run example/form/email_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Case@example.com\r',
  (io) => FormTheme(io: io).emailInput(
    'Email',
    colors: ComponentColors.palette(ColorThemes.fieldnotes),
  ),
);
