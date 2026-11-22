import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// Slider — one component, one structural theme (ChevronTheme),
/// one colour theme (ColorThemes.midnightMint).
///
/// Run: dart run example/chevron/slider.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\x7f\x7f\x7f0.6\r',
  (io) => ChevronTheme(io: io).slider(
    'Volume',
    minimum: '0',
    maximum: '1',
    step: '0.2',
    initialValue: '0.4',
    colors: ComponentColors.palette(ColorThemes.midnightMint),
  ),
);
