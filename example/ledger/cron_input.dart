import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// CronInput — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.workbench).
///
/// Run: dart run example/ledger/cron_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '* * * * *\r/submit\r',
  (io) => LedgerTheme(io: io).cronInput(
    'Schedule',
    profile: CronProfile.unix,
    colors: ComponentColors.palette(ColorThemes.workbench),
  ),
);
