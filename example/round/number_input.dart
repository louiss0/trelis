import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// NumberInput — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.glacier).
///
/// Run: dart run example/round/number_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '12\r',
  (io) => RoundTheme(io: io).numberInput(
    'Count',
    convention: NumericConvention.ascii(),
    colors: ComponentColors.palette(ColorThemes.glacier),
  ),
);
