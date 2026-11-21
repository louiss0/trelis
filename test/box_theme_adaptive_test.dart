import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/src/choice_tracer.dart';
import 'package:trelis/src/color_resolution.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/state_help_presentation.dart';
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

  test('a real Box choice renders focus, selection and default independently',
      () async {
    final output = StringBuffer();
    final tracer = ThemeChoiceTracer<String>(
      'Choose features',
      _choices,
      io: TerminalEnvironment.scripted(
        input: Stream.value('\r'),
        output: output,
        profile: _rgbProfile,
      ),
      structure: PromptStructure.box,
      palettes: StructuralThemePalettes.box.defaults,
      defaultValues: const ['starter'],
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      themeColors: const ColorPreferences(
        background: BackgroundPreference.dark,
      ),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<List<String>>).value, ['starter']);
    final text = output.toString();
    expect(text, contains('┌'));
    expect(text, contains('└'));
    expect(text, contains('[focused]'));
    expect(text, contains('[default]'));
    expect(text, contains('[checked]'));
    expect(text, contains('[unchecked]'));
    expect(text, contains('Not provisioned'));
    expect(text, contains('Enter submits'));
    expect(text, contains('Ctrl+T'));
    // The focused row uses the dark rust accent on the default surface.
    expect(text, contains('\x1b[38;2;232;135;90;49m'));
    expect(text, isNot(contains('\x1b[48;2;')));
  });

  test('a Box choice keeps its structure and markers without colour', () async {
    final output = StringBuffer();
    final tracer = ThemeChoiceTracer<String>(
      'Choose features',
      _choices,
      io: TerminalEnvironment.scripted(
        input: Stream.value('\r'),
        output: output,
        profile: OutputProfile(
          cursor: CapabilitySupport.supported,
          styles: CapabilitySupport.supported,
          colorDepth: ColorDepth.none,
          geometry: OutputGeometry.fixed(columns: 40, rows: 12),
          glyphs: GlyphSet.ascii,
        ),
      ),
      structure: PromptStructure.box,
      palettes: StructuralThemePalettes.box.defaults,
      defaultValues: const ['starter'],
      interaction: const InteractionPreferences(mode: PromptMode.rich),
      themeColors: const ColorPreferences(
        background: BackgroundPreference.light,
      ),
    );

    final result = await tracer.prompt();

    expect((result as Accepted<List<String>>).value, ['starter']);
    final text = output.toString();
    expect(text, contains('+---'));
    expect(text, contains('[focused]'));
    expect(text, contains('[default]'));
    expect(text, contains('[checked]'));
    expect(text, contains('[unchecked]'));
    expect(text, contains('Not provisioned'));
    expect(text, contains('Ctrl+T'));
    expect(text, isNot(contains('\x1b[3')));
    expect(text, isNot(contains('\x1b[4')));
    expect(text, isNot(contains('\x1b[?1049h')));
    for (final line in _plainLines(text)) {
      expect(line.length, lessThanOrEqualTo(40), reason: line);
    }
  });

  test('Box state glyphs keep focus, selection, default and status separate',
      () {
    final row = ChoicePresentation(
      label: 'Starter',
      focused: true,
      checked: true,
      isDefault: true,
    );
    final ascii = row.markers(glyphs: StateGlyphs.ascii);
    expect(ascii.focus, '>');
    expect(ascii.selection, 'x');
    expect(ascii.defaultMarker, 'D');
    final plain = ChoicePresentation(label: 'Library', checked: false)
        .markers(glyphs: StateGlyphs.ascii);
    expect(plain.selection, '-');
    expect(plain.focus, ' ');
    expect(
      renderStatus(Status.warning, 'Not provisioned', glyphs: StateGlyphs.ascii),
      '! Warning: Not provisioned',
    );
  });
}

List<String> _plainLines(String text) => [
  for (final line in text.split('\n'))
    line.replaceAll(RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]'), ''),
];

final _choices = <Choice<String>>[
  Choice('starter', 'Starter'),
  Choice('library', 'Library'),
  Choice('legacy', 'Legacy', disabledReason: 'Not provisioned'),
];

final _rgbProfile = OutputProfile(
  cursor: CapabilitySupport.supported,
  styles: CapabilitySupport.supported,
  colorDepth: ColorDepth.rgb,
  geometry: OutputGeometry.fixed(columns: 60, rows: 12),
  glyphs: GlyphSet.unicode,
);
