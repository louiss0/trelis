/// Internal, default-off Windows screen-reader hint binding.
///
/// This reads the documented `SystemParametersInfo(SPI_GETSCREENREADER)`
/// parameter. Windows accessibility aids typically set it, but Narrator does
/// not; a negative result is not proof that no screen reader is running, and a
/// positive result says nothing about which terminal output is being read.
/// Locality and explicit preferences remain the caller's responsibility.
///
/// This library is not exported from the public barrel. Enabling the probe by
/// default is a later rollout decision after real platform evidence.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'hint_observations.dart' show HintPlatform;
import 'interaction_resolution.dart' show ScreenReaderObservation;

/// Win32 `SystemParametersInfoW` action `SPI_GETSCREENREADER`.
const int spiGetScreenReader = 0x004f;

/// Native call shape: writes a Win32 BOOL into [value] and returns whether the
/// query itself succeeded as a Win32 BOOL. Nullable so a failed or unusable
/// call can report no result without an exception.
typedef WindowsReaderNativeCall = int? Function(Pointer<Uint32> value);

/// Supplies the native binding, or null when no callable binding exists.
typedef WindowsReaderBindingLookup = WindowsReaderBinding? Function();

/// Win64 has one native calling convention, which matches Dart's FFI C ABI.
/// The Win32 x86 stdcall convention cannot be expressed by this SDK's FFI
/// API, so x86 is treated as a missing binding rather than called unsafely.
typedef _SystemParametersInfoNative = Int32 Function(
  Uint32 uiAction,
  Uint32 uiParam,
  Pointer<Void> pvParam,
  Uint32 fWinIni,
);

typedef _SystemParametersInfoDart = int Function(
  int uiAction,
  int uiParam,
  Pointer<Void> pvParam,
  int fWinIni,
);

/// Looks up the documented Windows API on Windows only.
///
/// A missing library, symbol or unsupported platform is a missing binding,
/// never an interaction failure.
WindowsReaderBinding? platformWindowsReaderBinding() {
  if (!Platform.isWindows) return null;
  final abi = Abi.current();
  if (abi != Abi.windowsX64 && abi != Abi.windowsArm64) return null;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final systemParametersInfo = user32
        .lookupFunction<_SystemParametersInfoNative, _SystemParametersInfoDart>(
          'SystemParametersInfoW',
        );
    return WindowsReaderBinding(
      call: (value) =>
          systemParametersInfo(spiGetScreenReader, 0, value.cast<Void>(), 0),
    );
  } catch (_) {
    return null;
  }
}

/// One injected native call with its output allocation.
final class WindowsReaderBinding {
  WindowsReaderBinding({required this.call, Allocator? allocate})
    : allocate = allocate ?? calloc;

  /// The native call, injected so both BOOL results can be tested.
  final WindowsReaderNativeCall call;

  /// The allocator that owns the native BOOL cell.
  final Allocator allocate;

  /// Reads one parameter value, returning unknown for every unusable result.
  ScreenReaderObservation read() {
    Pointer<Uint32>? value;
    try {
      value = allocate<Uint32>(sizeOf<Uint32>());
      value.value = 0;
      if (call(value) != 1) return ScreenReaderObservation.unknown;
      return switch (value.value) {
        1 => ScreenReaderObservation.positive,
        0 => ScreenReaderObservation.negative,
        _ => ScreenReaderObservation.unknown,
      };
    } catch (_) {
      return ScreenReaderObservation.unknown;
    } finally {
      if (value != null) allocate.free(value);
    }
  }
}

/// An opt-in probe shaped for [NativeHintObservations.readerProbe].
///
/// The rollout gate is off unless constructed with [enabled] set to true.
/// Locality, explicit preferences and once-per-period collection are applied
/// downstream; this probe only classifies one native parameter reading.
final class WindowsReaderProbe {
  WindowsReaderProbe({
    this.enabled = false,
    bool Function()? isWindows,
    WindowsReaderBindingLookup? lookup,
  }) : _isWindows = isWindows ?? _defaultIsWindows,
       _lookup = lookup ?? platformWindowsReaderBinding;

  /// Default-off rollout gate; enable only after real platform evidence.
  final bool enabled;

  final bool Function() _isWindows;
  final WindowsReaderBindingLookup _lookup;

  /// Returns unknown without querying native code when the gate is off, the
  /// platform or requested hint family is not Windows, or the binding is
  /// missing.
  ScreenReaderObservation call(HintPlatform platform) {
    if (!enabled || platform != HintPlatform.windows || !_isWindows()) {
      return ScreenReaderObservation.unknown;
    }
    final WindowsReaderBinding? binding;
    try {
      binding = _lookup();
    } catch (_) {
      return ScreenReaderObservation.unknown;
    }
    if (binding == null) return ScreenReaderObservation.unknown;
    return binding.read();
  }
}

bool _defaultIsWindows() => Platform.isWindows;
