import 'package:trelis/src/structural_theme_palettes.dart';
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates Box's adaptive defaults and a separate explicit override.
///
/// Run: dart example/box_theme_example.dart
///
/// The adaptive light/dark defaults are internal until the coordinated public
/// cutover. Here they are injected into the theme-owned tracer, which renders
/// a real Box component. The public `BoxTheme` factories still default to
/// terminal-native colours, so an explicit palette is a separate override and
/// is not an example of the adaptive defaults.
void main() {
  final io = TerminalEnvironment.scripted(
    input: const Stream<String>.empty(),
    output: StringBuffer(),
  );

  // Adaptive defaults at the internal cutover seam: the same tracer accepts
  // the authored Box light and dark palettes without changing public calls.
  final adaptive = ThemeTextInputTracer(
    'Project name',
    io: io,
    structure: PromptStructure.box,
    palettes: StructuralThemePalettes.box.defaults,
  );

  // A separate explicit colour override at the still-public factory seam.
  final explicit = BoxTheme.textInput(
    'Project name',
    colors: ColorThemes.punch.copyWith(accent: TerminalColor.rgb(166, 69, 38)),
  );

  print('Configured:');
  print(
    '  adaptive: ${adaptive.label} with authored Box light/dark defaults '
    '(internal seam, not a public default yet)',
  );
  print(
    '  explicit: ${explicit.label} with a caller-supplied rust accent '
    '(public factory override)',
  );
  print(
    '  public omission: ${BoxTheme.textInput('Project name').colors == ColorThemes.terminalDefault ? 'terminal-native' : 'adaptive'}',
  );
}
