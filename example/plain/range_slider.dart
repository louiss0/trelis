import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// RangeSlider — one component, one structural theme (PlainTheme),
/// one colour theme (ColorThemes.deepSpace).
///
/// Run: dart run example/plain/range_slider.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '\x7f2\r\x7f8\r\r',
  (io) => PlainTheme(io: io).rangeSlider(
    'Window',
    minimum: '0',
    maximum: '10',
    step: '1',
    initialLower: '3',
    initialUpper: '5',
    minimumGap: '2',
    colors: ComponentColors.palette(ColorThemes.deepSpace),
  ),
);
