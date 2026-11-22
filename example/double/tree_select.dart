import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TreeSelect — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.polar).
///
/// Run: dart run example/double/tree_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/choose\r2\r',
  (io) => DoubleTheme(io: io).treeSelect<String>(
    'Tree',
    [TreeNode('a', 'A'), TreeNode('b', 'B')],
    defaultValue: 'b',
    colors: ComponentColors.palette(ColorThemes.polar),
  ),
);
