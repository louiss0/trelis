import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (LineTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/line/text.dart
Future<void> main(List<String> arguments) async {
  final theme = LineTheme(
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
