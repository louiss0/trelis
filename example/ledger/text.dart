import 'package:trelis/trelis.dart';

/// Text — one component, one structural theme (LedgerTheme),
/// one colour theme (ColorThemes.blueHour).
///
/// Run: dart run example/ledger/text.dart
Future<void> main(List<String> arguments) async {
  final theme = LedgerTheme(
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
