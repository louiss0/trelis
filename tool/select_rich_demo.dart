import 'package:trelis/trelis.dart';

/// Runs a rich-mode Select with two down-arrow navigations and prints the raw
/// output with escape sequences visible, to show whether the choice list
/// redraws in place or appends.
Future<void> main() async {
  final out = StringBuffer();
  final profile = OutputProfile(
    cursor: CapabilitySupport.supported,
    geometry: OutputGeometry.fixed(columns: 40, rows: 12),
    glyphs: GlyphSet.ascii,
  );
  final source = ScriptedInput(
    Stream.fromIterable(['\x1b[B', '\x1b[B', '\r']),
    out,
    supportsRich: true,
    outputProfile: profile,
  );
  final result = await RailTheme.select<String>('Deploy target', [
    Choice('staging', 'Staging'),
    Choice('production', 'Production'),
  ]).prompt(source: source, mode: PromptMode.rich);
  final escaped = out
      .toString()
      .replaceAll('\r', r'\r')
      .replaceAll('\x1b', r'\x1b');
  print('--- rich Select output (escapes visible) ---');
  print(escaped);
  print('--- result: ${result.runtimeType} ---');
}
