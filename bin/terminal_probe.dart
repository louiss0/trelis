import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// A narrowly scoped Windows console probe. It owns stdin only while reading;
// prompt output is stderr and machine-readable results are stdout.
void main(List<String> args) {
  if (!Platform.isWindows || !stdin.hasTerminal || !stderr.hasTerminal) {
    stderr.writeln(
      'rich interaction unavailable: console stdin and stderr required',
    );
    exitCode = 2;
    return;
  }
  final api = _Console();
  final input = api.getHandle(-10);
  final output = api.getHandle(-12);
  final inputMode = calloc<Uint32>();
  final outputMode = calloc<Uint32>();
  try {
    if (api.getMode(input, inputMode) == 0 ||
        api.getMode(output, outputMode) == 0) {
      stderr.writeln('rich interaction unavailable: console handles required');
      exitCode = 2;
      return;
    }
    final sessions = args.contains('--twice') ? 2 : 1;
    for (var i = 0; i < sessions; i++) {
      final original = inputMode.value;
      // Disable processed, line and echo input; enable VT input.
      if (api.setMode(input, (original | 0x200) & ~0x7) == 0) {
        stderr.writeln(
          'rich interaction unavailable: cannot enable console input',
        );
        exitCode = 2;
        return;
      }
      String result;
      try {
        stderr.write('probe ${i + 1}> ');
        final text = StringBuffer();
        while (true) {
          final byte = stdin.readByteSync();
          if (byte == -1 || byte == 26) {
            result = 'eof';
            break;
          }
          if (byte == 3) {
            result = 'interrupt';
            break;
          }
          if (byte == 27) {
            result = 'cancel';
            break;
          }
          if (byte == 13 || byte == 10) {
            result = 'submit:${text.toString()}';
            break;
          }
          if (byte >= 32 && byte < 127) {
            if (text.length == 5) {
              throw const FormatException(
                'probe input exceeds five characters',
              );
            }
            text.writeCharCode(byte);
          }
        }
      } on FormatException {
        result = 'error';
      } finally {
        if (api.setMode(input, original) == 0) {
          throw StateError('failed to restore console input mode');
        }
      }
      stderr.writeln();
      stdout.writeln(result);
    }
  } finally {
    calloc.free(inputMode);
    calloc.free(outputMode);
  }
}

final class _Console {
  final _dll = DynamicLibrary.open('kernel32.dll');
  late final int Function(int) getHandle = _dll
      .lookupFunction<IntPtr Function(Int32), int Function(int)>(
        'GetStdHandle',
      );
  late final int Function(int, Pointer<Uint32>) getMode = _dll
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');
  late final int Function(int, int) setMode = _dll
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );
}
