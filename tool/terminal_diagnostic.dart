import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Reports every fact the package gathers to choose rich vs. linear mode,
/// including the Windows cursor/VT condition that `hasTerminal` alone does not
/// express. Run it in the terminal where you saw the append-at-bottom:
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
  if (Platform.isWindows) {
    _reportCursorVt();
  }
}

int? _trySize(int Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

/// The Windows-only cursor/VT condition: can the console output handle enable
/// ENABLE_VIRTUAL_TERMINAL_PROCESSING (bit 4), which the package requires for
/// in-place redraw. This is what `hasTerminal` does not tell you.
void _reportCursorVt() {
  const stdOutputHandle = -11;
  const stdErrorHandle = -12;
  const enableVirtualTerminalProcessing = 4;
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getStdHandle = kernel32
      .lookupFunction<IntPtr Function(Int32), int Function(int)>(
        'GetStdHandle',
      );
  final getConsoleMode = kernel32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');
  final setConsoleMode = kernel32
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );

  for (final (name, stdHandle) in [
    ('stdout handle', stdOutputHandle),
    ('stderr handle', stdErrorHandle),
  ]) {
    final handle = getStdHandle(stdHandle);
    if (handle == 0 || handle == -1) {
      print('$name: GetStdHandle returned invalid handle');
      continue;
    }
    final mode = calloc<Uint32>();
    final got = getConsoleMode(handle, mode);
    if (got == 0) {
      print('$name: GetConsoleMode FAILED (not a console handle)');
      calloc.free(mode);
      continue;
    }
    final original = mode.value;
    final enabled = setConsoleMode(
      handle,
      original | enableVirtualTerminalProcessing,
    );
    // Restore the original mode so the probe leaves the console untouched.
    setConsoleMode(handle, original);
    print(
      '$name: VT enable ${enabled != 0 ? 'SUCCEEDED (cursor addressing available)' : 'FAILED (no in-place redraw)'}',
    );
    calloc.free(mode);
  }
}
