import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Autocomplete — one component, one structural theme (RoundTheme),
/// one colour theme (ColorThemes.paper).
///
/// Run: dart run example/round/autocomplete.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'A\r1\r/submit\r',
  (io) => RoundTheme(io: io).autocomplete(
    'Suggestion',
    suggestions: (_) => ['Ada'],
    colors: ComponentColors.palette(ColorThemes.paper),
  ),
);
