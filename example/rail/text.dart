import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (RailTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/rail/text.dart
Future<void> main(List<String> arguments) async {
  final theme = RailTheme(
    interaction: const InteractionPreferences(mode: PromptMode.linear),
  );
  await theme
      .text(
        'Configuration saved',
        kind: TextKind.success,
        colors: ComponentColors.palette(ColorThemes.blueHour),
      )
      .present();
}
