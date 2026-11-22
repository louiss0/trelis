import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Autocomplete — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.paper).
///
/// Run: dart run example/form/autocomplete.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  'A\r1\r/submit\r',
  (io) => FormTheme(io: io).autocomplete(
    'Suggestion',
    suggestions: (_) => ['Ada'],
    colors: ComponentColors.palette(ColorThemes.paper),
  ),
);
