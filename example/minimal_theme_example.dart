// ignore_for_file: avoid_print

import 'package:trelis/src/themes/minimal_presentation.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates the internal, unstable Minimal adaptive presentation seam.
///
/// Run: `dart run example/minimal_theme_example.dart`
///
/// The public `MinimalTheme` factories still take an explicit `ColorTheme` and
/// keep terminal-native colours by default until the coordinated cutover. This
/// scripted example exercises the internal owner seam instead: two authored
/// adaptive defaults selected by explicit background, then a separate
/// application-provided whole-palette replacement. It is evidence for the
/// migration, not a stable API or a claim about real terminal contrast.
Future<void> main() async {
  await _show(
    'Minimal light default',
    colors: const ColorPreferences(background: BackgroundPreference.light),
  );
  await _show(
    'Minimal dark default',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );

  final explicit = ColorThemes.terminalDefault.copyWith(
    foreground: TerminalColor.rgb(45, 38, 34),
    accent: TerminalColor.rgb(116, 42, 88),
  );
  await _show(
    'Minimal with an explicit application palette',
    colors: ColorPreferences(
      background: BackgroundPreference.dark,
      colors: ComponentColors.palette(explicit),
    ),
  );
}

Future<void> _show(
  String title, {
  required ColorPreferences colors,
  ComponentColors component = const ComponentColors(),
}) async {
  final output = StringBuffer();
  final tracer = MinimalPresentationTracer(
    io: TerminalEnvironment.scripted(
      input: Stream.value('\r'),
      output: output,
      profile: OutputProfile(
        cursor: CapabilitySupport.supported,
        colorDepth: ColorDepth.rgb,
        glyphs: GlyphSet.unicode,
        geometry: OutputGeometry.fixed(columns: 60, rows: 12),
      ),
    ),
    colors: colors,
    componentColors: component,
    interaction: const InteractionPreferences(mode: PromptMode.rich),
  );

  final result = await tracer.select<String>('Choose a feature', [
    Choice('starter', 'Starter'),
    Choice('library', 'Library'),
  ], defaultValue: 'starter');
  final answer = result is Accepted<String> ? result.value : result.runtimeType;

  print(title);
  print('  answer: $answer');
  print(output.toString().replaceAll('\x1b', '<ESC>').trimRight());
}
