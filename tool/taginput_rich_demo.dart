import 'package:trelis/src/testing/compat_api.dart';

/// Runs a rich-mode TagInput, types a tag, and prints the raw output with
/// escape sequences visible.
Future<void> main() async {
  final out = StringBuffer();
  final profile = OutputProfile(
    cursor: CapabilitySupport.supported,
    geometry: OutputGeometry.fixed(columns: 40, rows: 12),
    glyphs: GlyphSet.ascii,
  );
  final source = ScriptedInput(
    Stream.fromIterable(['a', 'b', '\r']),
    out,
    supportsRich: true,
    outputProfile: profile,
  );
  final result = await RailTheme.tagInput('Tags')
      .prompt(source: source, mode: PromptMode.rich);
  final escaped = out
      .toString()
      .replaceAll('\r', r'\r')
      .replaceAll('\x1b', r'\x1b');
  print('--- rich TagInput output (escapes visible) ---');
  print(escaped);
  print('--- result: ${result.runtimeType} ---');
}
