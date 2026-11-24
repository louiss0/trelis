import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (DoubleTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/double/text.dart
Future<void> main(List<String> arguments) async {
  final theme = DoubleTheme(
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
