import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// CronInput — one component, one structural theme (AsciiTheme),
/// one colour theme (ColorThemes.workbench).
///
/// Run: dart run example/ascii/cron_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '* * * * *\r/submit\r',
  (io) => AsciiTheme(io: io).cronInput(
    'Schedule',
    profile: CronProfile.unix,
    colors: ComponentColors.palette(ColorThemes.workbench),
  ),
);
