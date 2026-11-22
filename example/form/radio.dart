import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Radio — one component, one structural theme (FormTheme),
/// one colour theme (ColorThemes.solar).
///
/// Run: dart run example/form/radio.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r',
  (io) => FormTheme(io: io).radio<String>('Signal', [
    Choice('a', 'Red'),
    Choice('b', 'Green'),
  ], colors: ComponentColors.palette(ColorThemes.solar)),
);
