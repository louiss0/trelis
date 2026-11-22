import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// NumberInput — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.glacier).
///
/// Run: dart run example/colon/number_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '12\r',
  (io) => ColonTheme(io: io).numberInput(
    'Count',
    convention: NumericConvention.ascii(),
    colors: ComponentColors.palette(ColorThemes.glacier),
  ),
);
