import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/structural_theme_palettes.dart';
import 'package:trelis/src/text_input_tracer.dart';
import 'package:trelis/trelis.dart';

/// Internal-seam evidence for the Box adaptive defaults.
///
/// The public static factories stay on `ColorThemes.terminalDefault` until the
/// coordinated cutover; these tests exercise a real component through the
/// theme-owned tracer with the authored Box light/dark defaults injected.
void main() {
  test('a Box text input renders the light default through the internal seam',
      () async {
    final output = StringBuffer();
    final tracer = ThemeTextInputTracer(
      'Project name',
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: output,
        profile: _rgbProfile,
      ),
      structure: PromptStructure.box,
      palettes: StructuralThemePalettes.box.defaults,
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      themeColors: const ColorPreferences(
        background: BackgroundPreference.light,
      ),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<String>).value, 'Ada');
    final text = output.toString();
    expect(text, contains('┌'));
    expect(text, contains('└'));
    // Warm-ink foreground and rust border are painted on the terminal default
    // surface, never on a whole-screen background.
    expect(text, contains('\x1b[38;2;51;41;31;49m'));
    expect(text, contains('\x1b[38;2;122;102;80;49m'));
    expect(text, isNot(contains('\x1b[48;2;')));
    expect(text, contains('Ctrl+T'));
  });
}

final _rgbProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
  glyphs: GlyphSet.unicode,
);
