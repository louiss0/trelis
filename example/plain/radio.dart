import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Radio — one component, one structural theme (PlainTheme),
/// one colour theme (ColorThemes.solar).
///
/// Run: dart run example/plain/radio.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r',
  (io) => PlainTheme(io: io).radio<String>('Signal', [
    Choice('a', 'Red'),
    Choice('b', 'Green'),
  ], colors: ComponentColors.palette(ColorThemes.solar)),
);
