// ignore_for_file: avoid_print

import 'dart:async';

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/ledger_adaptive_theme.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates Ledger's adaptive sepia defaults and a separate explicit
/// colour override at the internal cutover seam.
///
/// Run: dart example/ledger_theme_example.dart
///
/// The public static [LedgerTheme] factories remain the supported pre-cutover
/// API. The adaptive defaults are exercised here through the internal theme
/// seam so examples do not accidentally present the old atlas palettes as
/// defaults. Construction is output-free; prompts need a scripted environment
/// or a terminal owner.
void main() {
  final io = TerminalEnvironment.scripted(
    input: const Stream<String>.empty(),
    output: StringBuffer(),
  );

  // Adaptive defaults: omission resolves to Ledger's authored warm-ink pair.
  // An unknown background falls back to dark; a passive hint can select light.
  final ledger = LedgerAdaptiveTheme(io: io);
  final unknown = resolveLedgerColors(facts: const ColorDetectionFacts());
  final light = resolveLedgerColors(
    facts: const ColorDetectionFacts(
      passiveBackground: BackgroundObservation.light,
    ),
  );
  print(
    'Ledger defaults (${unknown.background.name} fallback): '
    '${unknown.palette.accent == LedgerAdaptivePalettes.dark.accent ? 'dark sepia' : 'unexpected'}',
  );
  print(
    'Ledger defaults (${light.background.name} hint): '
    '${light.palette.accent == LedgerAdaptivePalettes.light.accent ? 'light sepia' : 'unexpected'}',
  );

  // A separate application choice: replace the whole component palette rather
  // than redefining Ledger's defaults.
  final explicit = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(40, 45, 50),
    accent: TerminalColor.rgb(32, 92, 197),
  );
  final overridden = LedgerAdaptiveTheme(
    io: io,
    component: ComponentColors.palette(explicit),
  );
  print(
    'Explicit component override accent: '
    '${overridden.component.palette!.accent == explicit.accent ? 'override applied' : 'unexpected'}',
  );
  print(
    'Configured prompts through the internal seam: '
    '${ledger.component.palette == null ? 'theme defaults' : 'override'}',
  );
}
