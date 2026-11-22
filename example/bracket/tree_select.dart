import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TreeSelect — one component, one structural theme (BracketTheme),
/// one colour theme (ColorThemes.polar).
///
/// Run: dart run example/bracket/tree_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/choose\r2\r',
  (io) => BracketTheme(io: io).treeSelect<String>(
    'Tree',
    [TreeNode('a', 'A'), TreeNode('b', 'B')],
    defaultValue: 'b',
    colors: ComponentColors.palette(ColorThemes.polar),
  ),
);
