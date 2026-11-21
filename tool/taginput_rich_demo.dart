import 'package:trelis/trelis.dart';

/// Runs a rich-mode TagInput, types a tag, and prints the raw output with
/// escape sequences visible.
Future<void> main() async {
  final out = StringBuffer();
  final profile = OutputProfile(
    cursor: CapabilitySupport.supported,
    geometry: OutputGeometry.fixed(columns: 40, rows: 12),
    glyphs: GlyphSet.ascii,
  );
  final theme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.fromIterable(['a', 'b', '\r']),
      output: out,
      profile: profile,
      supportsRich: true,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.rich),
  );
  final result = await theme.tagInput('Tags').prompt();
  final escaped = out
      .toString()
      .replaceAll('\r', r'\r')
      .replaceAll('\x1b', r'\x1b');
  print('--- rich TagInput output (escapes visible) ---');
  print(escaped);
  print('--- result: ${result.runtimeType} ---');
}
