import 'dart:io';

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/chevron_theme_internal.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates Chevron's adaptive defaults and a separate explicit override.
///
/// This uses the internal theme-owner seam, not a stable public `ChevronTheme`
/// instance: the coordinated public cutover is a later ticket. The scripted
/// environment and pinned background make the example runnable without a
/// terminal; a real application can leave the background automatic so the theme
/// owner selects the light or dark authored default.
Future<void> _show({
  required String title,
  required ColorPreferences colors,
  ComponentColors component = const ComponentColors(),
}) async {
  stdout.writeln('\n$title');
  final theme = ChevronInternalPresentation(
    io: TerminalEnvironment.scripted(
      input: Stream.value('Ada\r'),
      output: stdout,
      profile: OutputProfile(
        cursor: CapabilitySupport.supported,
        geometry: OutputGeometry.fixed(columns: 72, rows: 20),
        glyphs: GlyphSet.unicode,
        colorDepth: ColorDepth.rgb,
      ),
    ),
    interaction: const InteractionPreferences(mode: PromptMode.rich),
    colors: colors,
  );
  final result = await theme.textInput('Project name', colors: component);
  stdout.writeln(
    result is Accepted<String>
        ? 'Accepted: ${result.value}'
        : 'Stopped: ${result.runtimeType}',
  );
}

Future<void> main() async {
  await _show(
    title: 'Authored light default (Atelier Sepia direction, ink-blue accent)',
    colors: const ColorPreferences(background: BackgroundPreference.light),
  );
  await _show(
    title: 'Authored dark default (warm ink, ink-blue accent)',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );
  await _show(
    title: 'Explicit application palette replacement',
    colors: ColorPreferences(
      background: BackgroundPreference.dark,
      colors: ComponentColors.palette(ColorThemes.deepSpace),
    ),
  );
  await _show(
    title: 'Explicit component palette replacement',
    colors: const ColorPreferences(background: BackgroundPreference.light),
    component: ComponentColors.palette(ColorThemes.paper),
  );
}
