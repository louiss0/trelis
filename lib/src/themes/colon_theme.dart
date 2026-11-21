import 'package:trelis/src/color_resolution.dart' show ThemePaletteDefaults;
import 'package:trelis/src/prompt_structure.dart' show PromptStructure;
import 'package:trelis/src/public_theme_api.dart' show StructuralTheme;

import 'package:trelis/src/themes/colon_theme_internal.dart'
    show ColonPaletteDefaults;

/// Colon structural theme instance.
///
/// The theme owns its I/O environment and active period. All component
/// creation happens through inherited instance methods; there is no public
/// close method and no invocation-level configuration.
final class ColonTheme extends StructuralTheme {
  ColonTheme({
    super.io,
    super.interaction,
    super.colors,
    super.selectionStyle,
    super.onResolved,
    super.hints,
  }) : super(
         structure: PromptStructure.colon,
         palettes: ThemePaletteDefaults(
           light: ColonPaletteDefaults.light,
           dark: ColonPaletteDefaults.dark,
         ),
       );
}
