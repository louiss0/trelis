import 'dart:async';

import 'package:test/test.dart';
import 'package:trelis/trelis.dart';

void main() {
  TerminalEnvironment environment(String input, StringBuffer output) =>
      TerminalEnvironment.scripted(
        input: Stream.value(input),
        output: output,
        profile: OutputProfile(
          cursor: CapabilitySupport.supported,
          glyphs: GlyphSet.unicode,
          geometry: OutputGeometry.fixed(columns: 80, rows: 24),
        ),
      );

  test('Select uses the compact gutter through the public theme API', () async {
    final output = StringBuffer();
    final theme = PlainTheme(
      io: environment('\x1b[B\r', output),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    );

    final result = await theme.select('Choice', [
      Choice('a', 'First'),
      Choice('b', 'Second'),
    ]).prompt();

    expect(
      result,
      isA<Accepted<String>>().having((r) => r.value, 'value', 'b'),
    );
    // Dots make the eight-column gutter's spaces explicit in the assertion.
    expect(
      output.toString(),
      contains('·○··→···1. First'.replaceAll('·', ' ')),
    );
    expect(
      output.toString(),
      contains('·○··→···2. Second'.replaceAll('·', ' ')),
    );
  });

  test('MultiSelect keeps compact rows aligned while toggling', () async {
    final output = StringBuffer();
    final theme = PlainTheme(
      io: environment(' \x1b[B \r', output),
      interaction: const InteractionPreferences(mode: PromptMode.rich),
    );

    final result = await theme.multiSelect('Choices', [
      Choice('a', 'Alpha'),
      Choice('b', 'Beta'),
    ]).prompt();

    expect(
      result,
      isA<Accepted<List<String>>>().having((r) => r.value, 'value', ['a', 'b']),
    );
    expect(
      output.toString(),
      contains('·○··→···1. Alpha'.replaceAll('·', ' ')),
    );
    expect(
      output.toString(),
      contains('·✓··→···1. Alpha'.replaceAll('·', ' ')),
    );
    expect(output.toString(), contains('·✓··→···2. Beta'.replaceAll('·', ' ')));
  });
}
