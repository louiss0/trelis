import 'package:trelis/trelis.dart';

/// Simulates a rich-capable terminal and prints the raw output with escape
/// sequences made visible, so the in-place redraw (`\r\x1b[2K`) is obvious.
Future<void> main() async {
  final out = StringBuffer();
  final profile = OutputProfile(
    cursor: CapabilitySupport.supported,
    geometry: OutputGeometry.fixed(columns: 40, rows: 10),
    glyphs: GlyphSet.ascii,
  );
  final theme = RailTheme(
    io: TerminalEnvironment.scripted(
      input: Stream.fromIterable(['d', 'e', 'm', 'o', '\r']),
      output: out,
      profile: profile,
      supportsRich: true,
    ),
    interaction: const InteractionPreferences(mode: PromptMode.rich),
  );
  final result = await theme.textInput('Project name', required: true).prompt();
  final escaped = out
      .toString()
      .replaceAll('\r', r'\r')
      .replaceAll('\x1b', r'\x1b');
  print('--- rich-mode output (escape sequences visible) ---');
  print(escaped);
  print('--- result: ${result.runtimeType} ---');
}
