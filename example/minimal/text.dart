import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (MinimalTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/minimal/text.dart
Future<void> main(List<String> arguments) async {
  final theme = MinimalTheme(
    interaction: const InteractionPreferences(mode: PromptMode.automatic),
  );
  await theme
      .text(
        'Configuration saved',
        kind: TextKind.success,
        colors: ComponentColors.palette(ColorThemes.blueHour),
      )
      .present();
}
