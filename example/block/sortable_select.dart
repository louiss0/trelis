import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// SortableSelect — one component, one structural theme (BlockTheme),
/// one colour theme (ColorThemes.typewriter).
///
/// Run: dart run example/block/sortable_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/move\r2\r1\r/done\r',
  (io) => BlockTheme(io: io).sortableSelect<String>('Order', [
    Choice('a', 'A'),
    Choice('b', 'B'),
  ], colors: ComponentColors.palette(ColorThemes.typewriter)),
);
