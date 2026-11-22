import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Radio — one component, one structural theme (BranchTheme),
/// one colour theme (ColorThemes.solar).
///
/// Run: dart run example/branch/radio.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '2\r',
  (io) => BranchTheme(io: io).radio<String>('Signal', [
    Choice('a', 'Red'),
    Choice('b', 'Green'),
  ], colors: ComponentColors.palette(ColorThemes.solar)),
);
