import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/block_theme_presentation.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/trelis.dart';

final _rgbRichProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 72, rows: 20),
  glyphs: GlyphSet.unicode,
);

void main() {
  test('dark default renders a real Block text input with warm ink', () async {
    final out = StringBuffer();
    final theme = BlockThemePresentation(
      io: TerminalEnvironment.scripted(
        input: Stream.value('Ada\r'),
        output: out,
        profile: _rgbRichProfile,
        supportsRich: true,
      ),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      colors: const ColorPreferences(background: BackgroundPreference.dark),
    );

    final result = await theme.textInput('Project name');

    expect((result as Accepted<String>).value, 'Ada');
    expect(out.toString(), contains('PROJECT NAME'));
    expect(out.toString(), contains('█'));
    expect(out.toString(), contains('\x1b[38;2;232;224;209;49m'));
    expect(out.toString(), isNot(contains('\x1b[48;2;')));
    expect(out.toString(), isNot(contains('\x1b[2J')));
  });
}
