import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// DateInput — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.tide).
///
/// Run: dart run example/round/date_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '29/02/2024\r/submit\r',
  (io) => RoundTheme(io: io).dateInput(
    'Date',
    order: DateFieldOrder.dayMonthYear,
    colors: ComponentColors.palette(ColorThemes.tide),
  ),
);
