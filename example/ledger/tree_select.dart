import 'package:trelis/trelis.dart';

import '../support/one_component.dart';

/// TreeSelect — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.polar).
///
/// Run: dart run example/ledger/tree_select.dart [--scripted]
Future<void> main(List<String> arguments) => runOnePrompt(
  arguments,
  '/choose\r2\r',
  (io) => LedgerTheme(io: io).treeSelect<String>(
    'Tree',
    [TreeNode('a', 'A'), TreeNode('b', 'B')],
    defaultValue: 'b',
    colors: ComponentColors.palette(ColorThemes.polar),
  ),
);
