import 'package:trelis/src/prompt_structure.dart' show PromptStructure;
import 'package:trelis/src/public_theme_api.dart' show StructuralTheme;

import 'package:trelis/src/structural_theme_palettes.dart'
    show StructuralThemePalettes;

/// Box structural theme instance.
///
/// The theme owns its I/O environment and active period. All component
/// creation happens through inherited instance methods; there is no public
/// close method and no invocation-level configuration.
final class BoxTheme extends StructuralTheme {
  BoxTheme({
    super.io,
    super.interaction,
    super.colors,
    super.selectionStyle,
    super.onResolved,
    super.hints,
  }) : super(
         structure: PromptStructure.box,
         palettes: StructuralThemePalettes.box.defaults,
       );
}
