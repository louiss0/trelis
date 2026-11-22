import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// DurationInput — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.arcade).
///
/// Run: dart run example/branch/duration_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '1s\r',
  (io) => BranchTheme(io: io).durationInput(
    'Span',
    durationMode: DurationInputMode.elapsed,
    colors: ComponentColors.palette(ColorThemes.arcade),
  ),
);
