import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// DurationInput — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.arcade).
///
/// Run: dart run example/line/duration_input.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '1s\r',
  (io) => LineTheme(io: io).durationInput(
    'Span',
    durationMode: DurationInputMode.elapsed,
    colors: ComponentColors.palette(ColorThemes.arcade),
  ),
);
