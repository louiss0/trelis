import 'package:trelis/src/color_resolution.dart' show ThemePaletteDefaults;
import 'package:trelis/src/prompt_structure.dart' show PromptStructure;
import 'package:trelis/src/public_theme_api.dart' show StructuralTheme;

import 'package:trelis/src/ascii_ink_blue_theme.dart'
    show AsciiAdaptivePalettes;

/// Ascii structural theme instance.
///
/// The theme owns its I/O environment and active period. All component
/// creation happens through inherited instance methods; there is no public
/// close method and no invocation-level configuration.
final class AsciiTheme extends StructuralTheme {
  AsciiTheme({
    super.io,
    super.interaction,
    super.colors,
    super.selectionStyle,
    super.onResolved,
    super.hints,
  }) : super(
         structure: PromptStructure.ascii,
         palettes: ThemePaletteDefaults(
           light: AsciiAdaptivePalettes.light,
           dark: AsciiAdaptivePalettes.dark,
         ),
       );
}
