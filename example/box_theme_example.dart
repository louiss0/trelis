import 'package:trelis/trelis.dart';

/// Demonstrates Box's authored adaptive defaults and an explicit override.
///
/// Run: dart example/box_theme_example.dart
///
/// Omitting a component palette selects the theme light/dark default from the
/// owned output's background facts. The second prompt replaces the complete
/// effective palette explicitly. No theme close is needed.
Future<void> main() async {
  Future<PromptResult<String>> ask({
    required BackgroundPreference background,
    ComponentColors? colors,
  }) async {
    final theme = BoxTheme(
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: StringBuffer(),
      ),
      colors: ColorPreferences(background: background),
    );
    return theme
        .textInput('Project name', colors: colors ?? const ComponentColors())
        .prompt();
  }

  final light = await ask(background: BackgroundPreference.light);
  final dark = await ask(background: BackgroundPreference.dark);
  final explicit = await ask(
    background: BackgroundPreference.light,
    colors: ComponentColors.palette(ColorThemes.punch),
  );

  print('Light default: $light');
  print('Dark default: $dark');
  print('Explicit component palette: $explicit');
}
