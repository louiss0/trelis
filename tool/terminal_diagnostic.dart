import 'dart:io';

/// Reports the exact terminal facts the package gathers to choose rich vs.
/// linear mode. Run this in the terminal where you saw append-at-bottom:
///
///     dart run tool/terminal_diagnostic.dart
void main() {
  final term = Platform.environment['TERM'];
  final noColor = Platform.environment['NO_COLOR'];
  print('Platform            : ${Platform.operatingSystem}');
  print('stdin.hasTerminal   : ${stdin.hasTerminal}');
  print('stdout.hasTerminal  : ${stdout.hasTerminal}');
  print('stderr.hasTerminal  : ${stderr.hasTerminal}');
  print('TERM                : ${term ?? '<unset>'}');
  print('NO_COLOR            : ${noColor ?? '<unset>'}');
  for (final (name, stream) in [('stdout', stdout), ('stderr', stderr)]) {
    final cols = _trySize(() => stream.terminalColumns);
    final rows = _trySize(() => stream.terminalLines);
    print('$name terminal size  : $cols x $rows');
  }
}

int? _trySize(int Function() read) {
  try {
    return read();
  } catch (e) {
    return null;
  }
}
