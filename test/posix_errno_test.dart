import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:trelis/src/posix_errno.dart';

void main() {
  test('a library without an errno accessor resolves to none', () {
    if (Platform.isWindows) {
      expect(posixErrnoAccessor(DynamicLibrary.open('kernel32.dll')), isNull);
      return;
    }
    expect(
      posixErrnoAccessor(DynamicLibrary.process(), lookup: (_) => null),
      isNull,
    );
  });

  test('accessor spellings are probed in order until one resolves', () {
    final libc = Platform.isWindows
        ? DynamicLibrary.open('kernel32.dll')
        : DynamicLibrary.process();
    final cell = calloc<Int32>();
    final seen = <String>[];
    try {
      final resolved = posixErrnoAccessor(
        libc,
        lookup: (name) {
          seen.add(name);
          return name == '__errno' ? (() => cell) : null;
        },
      );
      expect(seen, ['__error', '__errno']);
      cell.value = 22;
      expect(resolved!().value, 22);
    } finally {
      calloc.free(cell);
    }
  });

  test('the process accessor reports a failed call as errno', () {
    final libc = DynamicLibrary.process();
    final accessor = posixErrnoAccessor(libc);
    expect(accessor, isNotNull);

    final access = libc
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int)
        >('access');
    final name = '/trelis/posix-errno-test/definitely-missing'.toNativeUtf8();
    try {
      // Read the thread-local cell before any matcher can run libc code.
      final result = access(name, 0);
      final code = accessor!().value;
      expect(result, -1);
      expect(code, 2); // ENOENT
    } finally {
      malloc.free(name);
    }
  }, skip: !Platform.isWindows ? false : 'requires a POSIX host');
}
