import 'dart:async';
import 'dart:io';

import 'package:trelis/trelis.dart';

/// Runs exactly one prompt component.
///
/// With a terminal attached the prompt reads real input. With `--scripted`, or
/// when stdout is redirected, it replays one fixed linear answer through a
/// scripted [TerminalEnvironment], so the component is still shown without a
/// terminal. Every component file calls this helper once: no example shows
/// two components.
Future<void> runOnePrompt(
  List<String> arguments,
  String answer,
  ThemePrompt<Object?> Function(TerminalEnvironment? io) create,
) async {
  final scripted = arguments.contains('--scripted') || !stdout.hasTerminal;
  final io = scripted
      ? TerminalEnvironment.scripted(
          input: Stream.value(answer),
          output: stdout,
          profile: const OutputProfile(colorDepth: ColorDepth.rgb),
          supportsRich: false,
        )
      : null;
  final result = await create(io).prompt();
  if (result is Accepted<Object?>) {
    stdout.writeln('Accepted: ${result.value}');
  } else if (result is Unavailable<Object?>) {
    stdout.writeln('Unavailable: ${result.reason}');
  } else {
    stdout.writeln(result.runtimeType);
  }
}

/// Absolute path to the checked-in atlas sheets.
///
/// Examples live at different depths (`example/prompt.dart` and
/// `example/<structure>/<component>.dart`), so the package root is found by
/// walking up from [Platform.script] instead of counting parents. The picker
/// examples need an absolute base containing only files, which keeps their
/// scripted `choose 1` answer stable on every platform.
String get atlasSheetsPath {
  var root = File.fromUri(Platform.script).parent;
  while (!File('${root.path}${Platform.pathSeparator}pubspec.yaml')
      .existsSync()) {
    final parent = root.parent;
    if (parent.path == root.path) {
      throw StateError('Cannot locate the package root from Platform.script.');
    }
    root = parent;
  }
  return Directory(
    '${root.path}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}prototype-themes'
    '${Platform.pathSeparator}sheets',
  ).absolute.path;
}
