import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TimeInput — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.matcha).
///
/// Run: dart run example/ledger/time_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\r',
  (io) => LedgerTheme(io: io).timeInput(
    'Time',
    initialValue: '23:59',
    colors: ComponentColors.palette(ColorThemes.matcha),
  ),
);
