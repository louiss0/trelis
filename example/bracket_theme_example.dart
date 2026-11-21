import 'dart:io';

import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/themes/bracket_theme_internal.dart';
import 'package:trelis/trelis.dart';

/// Demonstrates Bracket's adaptive defaults and a separate explicit override.
///
/// This uses the internal theme-owner seam, not a stable public `BracketTheme`
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
  final theme = BracketInternalPresentation(
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
    title: 'Authored light default (Atelier Sepia direction, rust accent)',
    colors: const ColorPreferences(background: BackgroundPreference.light),
  );
  await _show(
    title: 'Authored dark default (warm ink, rust accent)',
    colors: const ColorPreferences(background: BackgroundPreference.dark),
  );
  await _show(
    title: 'Explicit component palette replacement',
    colors: const ColorPreferences(background: BackgroundPreference.light),
    component: ComponentColors.palette(ColorThemes.paper),
  );

  // The still-public factory keeps its terminal-native omission; an explicit
  // palette is a separate caller override, not the adaptive default.
  final publicDefault = BracketTheme.textInput('Project name');
  stdout.writeln(
    '\nPublic factory omission: '
    '${publicDefault.colors == ColorThemes.terminalDefault ? 'terminal-native' : 'adaptive'}',
  );
  stdout.writeln(
    'Public explicit override: '
    '${BracketTheme.textInput('Project name', colors: ColorThemes.signal).colors.accent}',
  );
}
