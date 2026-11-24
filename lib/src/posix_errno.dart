/// Internal, POSIX-only binding for the thread-local errno accessor.
///
/// POSIX exposes errno through a function whose name varies by libc: BSD and
/// Darwin spell it `__error`, Android bionic and some BSDs spell it `__errno`,
/// illumos spells it `___errno`, and glibc and musl spell it
/// `__errno_location`. Dart's `Platform` API cannot name every POSIX host, so
/// the accessor is probed by symbol rather than selected by platform name.
///
/// This library is not exported from the public barrel.
library;

import 'dart:ffi';

/// Resolves the thread-local errno accessor in [libc], or null when none of
/// the known spellings exists.
///
/// Every resolved spelling returns a pointer to the caller's thread-local
/// errno cell, so the first symbol that resolves is correct regardless of
/// probe order. A null result means the platform's errno cannot be read and
/// callers must fall back to a non-errno answer. [lookup] is the symbol
/// resolution seam: it exists so tests can stand in for a library's symbols,
/// and a null or thrown result counts as a missing spelling.
Pointer<Int32> Function()? posixErrnoAccessor(
  DynamicLibrary libc, {
  Pointer<Int32> Function()? Function(String name)? lookup,
}) {
  final resolve =
      lookup ??
      (name) => libc
          .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
            name,
          );
  for (final name in const [
    '__error',
    '__errno',
    '___errno',
    '__errno_location',
  ]) {
    try {
      final resolved = resolve(name);
      if (resolved != null) return resolved;
    } catch (_) {
      // A missing spelling is not a failure; the next candidate may exist.
    }
  }
  return null;
}
