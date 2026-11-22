import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TextInput — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.signal).
///
/// Run: dart run example/ledger/text_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'Ada\r',
  (io) => LedgerTheme(io: io).textInput(
    'Deployment target',
    colors: ComponentColors.palette(ColorThemes.signal),
  ),
);
