import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (ColonTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/colon/text.dart
Future<void> main(List<String> arguments) async {
  final theme = ColonTheme(
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
