import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/interaction_resolution.dart';
import 'package:trelis/src/windows_reader_hint.dart';

void main() {
  test('a successful native BOOL true yields a positive observation', () {
    final binding = WindowsReaderBinding(
      call: (value) {
        value.value = 1;
        return 1;
      },
    );
    final probe = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => binding,
    );

    expect(probe(HintPlatform.windows), ScreenReaderObservation.positive);
  });

  test('a successful native BOOL false yields a negative observation', () {
    final binding = WindowsReaderBinding(
      call: (value) {
        value.value = 0;
        return 1;
      },
    );
    final probe = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => binding,
    );

    expect(probe(HintPlatform.windows), ScreenReaderObservation.negative);
  });

  test('failed, invalid and throwing native results stay unknown', () {
    final allocator = _CountingAllocator();
    final unusable = <({String name, WindowsReaderBinding binding})>[
      (
        name: 'failed call',
        binding: WindowsReaderBinding(call: (_) => 0, allocate: allocator),
      ),
      (
        name: 'no result',
        binding: WindowsReaderBinding(call: (_) => null, allocate: allocator),
      ),
      (
        name: 'invalid BOOL value',
        binding: WindowsReaderBinding(
          call: (value) {
            value.value = 2;
            return 1;
          },
          allocate: allocator,
        ),
      ),
      (
        name: 'throwing call',
        binding: WindowsReaderBinding(
          call: (_) => throw StateError('native fault'),
          allocate: allocator,
        ),
      ),
    ];

    for (final entry in unusable) {
      final probe = WindowsReaderProbe(
        enabled: true,
        isWindows: () => true,
        lookup: () => entry.binding,
      );
      expect(
        probe(HintPlatform.windows),
        ScreenReaderObservation.unknown,
        reason: entry.name,
      );
    }
    expect(allocator.allocations, unusable.length);
    expect(allocator.frees, allocator.allocations);
  });

  test('the gate and unsupported paths never reach native code', () {
    var calls = 0;
    final binding = WindowsReaderBinding(
      call: (value) {
        calls++;
        value.value = 1;
        return 1;
      },
    );

    final defaultOff = WindowsReaderProbe(
      isWindows: () => true,
      lookup: () => binding,
    );
    expect(defaultOff(HintPlatform.windows), ScreenReaderObservation.unknown);

    final otherFamily = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => binding,
    );
    expect(otherFamily(HintPlatform.macos), ScreenReaderObservation.unknown);

    final unsupported = WindowsReaderProbe(
      enabled: true,
      isWindows: () => false,
      lookup: () => binding,
    );
    expect(unsupported(HintPlatform.windows), ScreenReaderObservation.unknown);

    final missing = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => null,
    );
    expect(missing(HintPlatform.windows), ScreenReaderObservation.unknown);

    final failingLookup = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => throw StateError('missing user32'),
    );
    expect(
      failingLookup(HintPlatform.windows),
      ScreenReaderObservation.unknown,
    );

    expect(calls, 0);
  });

  test('a failed allocation stays unknown without blocking the prompt', () {
    final probe = WindowsReaderProbe(
      enabled: true,
      isWindows: () => true,
      lookup: () => WindowsReaderBinding(
        call: (value) {
          value.value = 1;
          return 1;
        },
        allocate: _ThrowingAllocator(),
      ),
    );

    expect(probe(HintPlatform.windows), ScreenReaderObservation.unknown);
  });
}

final class _CountingAllocator implements Allocator {
  int allocations = 0;
  int frees = 0;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    allocations++;
    return calloc.allocate<T>(byteCount, alignment: alignment);
  }

  @override
  void free(Pointer pointer) {
    frees++;
    calloc.free(pointer);
  }
}

final class _ThrowingAllocator implements Allocator {
  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) =>
      throw StateError('allocation unavailable');

  @override
  void free(Pointer pointer) {}
}
