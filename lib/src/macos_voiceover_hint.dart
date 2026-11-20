/// Internal, default-off binding for the documented macOS VoiceOver state.
///
/// This is VoiceOver-specific: it does not detect other screen readers or
/// assistive technology, and a negative result cannot veto a positive
/// application hint. Locality, explicit preferences and active-period caching
/// remain the responsibility of `NativeHintObservations` and `ThemeSession`.
/// Nothing here is exported from the public barrel, and this binding is not
/// qualified for automatic use until native and human evidence exists.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'hint_observations.dart' show HintPlatform, NativeReaderProbe;
import 'interaction_resolution.dart' show ScreenReaderObservation;

/// The rollout gate for this native hint.
///
/// It remains false until the separate enablement ticket is approved.
const bool macosVoiceOverHintEnabled = false;

const String _appKitPath = '/System/Library/Frameworks/AppKit.framework/AppKit';
const String _objcPath = '/usr/lib/libobjc.A.dylib';

/// The one-byte Objective-C call boundary needed for a VoiceOver observation.
///
/// Handles are opaque so injected implementations need not open a real native
/// library. The real implementation keeps every handle alive until the query
/// finishes and releases its autorelease pool and libraries in `finally`.
abstract interface class VoiceOverNativeBridge {
  Object open(String path);

  void close(Object library);

  Pointer<Void> findClass(Object runtime, String name);

  Pointer<Void> registerSelector(Object runtime, String name);

  bool respondsToSelector(
    Object runtime,
    Pointer<Void> object,
    Pointer<Void> respondsSelector,
    Pointer<Void> targetSelector,
  );

  Pointer<Void> sharedWorkspace(
    Object runtime,
    Pointer<Void> workspaceClass,
    Pointer<Void> selector,
  );

  /// Returns the raw Objective-C `BOOL` byte so invalid values stay unknown.
  int readVoiceOverEnabled(
    Object runtime,
    Pointer<Void> workspace,
    Pointer<Void> selector,
  );

  Object pushAutoreleasePool(Object runtime);

  void popAutoreleasePool(Object runtime, Object pool);
}

/// FFI calls into the Objective-C runtime for a real macOS observation.
///
/// Objective-C `BOOL` is byte-sized on both supported macOS architectures.
/// The raw byte is read so a value other than the canonical 0 or 1 cannot be
/// mistaken for a negative state. Autoreleased objects returned by
/// `sharedWorkspace` live inside the pool pushed for this one query.
final class FfiVoiceOverNativeBridge implements VoiceOverNativeBridge {
  const FfiVoiceOverNativeBridge();

  @override
  Object open(String path) => DynamicLibrary.open(path);

  @override
  void close(Object library) => (library as DynamicLibrary).close();

  @override
  Pointer<Void> findClass(Object runtime, String name) {
    final nativeName = name.toNativeUtf8();
    try {
      final getClass = (runtime as DynamicLibrary)
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf8>),
            Pointer<Void> Function(Pointer<Utf8>)
          >('objc_getClass');
      return getClass(nativeName);
    } finally {
      malloc.free(nativeName);
    }
  }

  @override
  Pointer<Void> registerSelector(Object runtime, String name) {
    final nativeName = name.toNativeUtf8();
    try {
      final registerName = (runtime as DynamicLibrary)
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf8>),
            Pointer<Void> Function(Pointer<Utf8>)
          >('sel_registerName');
      return registerName(nativeName);
    } finally {
      malloc.free(nativeName);
    }
  }

  @override
  bool respondsToSelector(
    Object runtime,
    Pointer<Void> object,
    Pointer<Void> respondsSelector,
    Pointer<Void> targetSelector,
  ) {
    final message = (runtime as DynamicLibrary)
        .lookupFunction<
          Uint8 Function(Pointer<Void>, Pointer<Void>, Pointer<Void>),
          int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>)
        >('objc_msgSend');
    return switch (message(object, respondsSelector, targetSelector)) {
      0 => false,
      1 => true,
      _ => throw StateError('Invalid Objective-C BOOL from respondsToSelector'),
    };
  }

  @override
  Pointer<Void> sharedWorkspace(
    Object runtime,
    Pointer<Void> workspaceClass,
    Pointer<Void> selector,
  ) {
    final message = (runtime as DynamicLibrary)
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>, Pointer<Void>)
        >('objc_msgSend');
    return message(workspaceClass, selector);
  }

  @override
  int readVoiceOverEnabled(
    Object runtime,
    Pointer<Void> workspace,
    Pointer<Void> selector,
  ) {
    final message = (runtime as DynamicLibrary)
        .lookupFunction<
          Uint8 Function(Pointer<Void>, Pointer<Void>),
          int Function(Pointer<Void>, Pointer<Void>)
        >('objc_msgSend');
    return message(workspace, selector);
  }

  @override
  Object pushAutoreleasePool(Object runtime) {
    final push = (runtime as DynamicLibrary)
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'objc_autoreleasePoolPush',
        );
    return push();
  }

  @override
  void popAutoreleasePool(Object runtime, Object pool) {
    final pop = (runtime as DynamicLibrary)
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('objc_autoreleasePoolPop');
    pop(pool as Pointer<Void>);
  }
}

/// Returns a probe suitable for `NativeHintObservations.readerProbe`.
///
/// The gate is off unless explicitly overridden for a platform fixture.
NativeReaderProbe macosVoiceOverReaderProbe({
  bool enabled = macosVoiceOverHintEnabled,
  VoiceOverNativeBridge? bridge,
}) =>
    (platform) =>
        observeVoiceOver(platform: platform, enabled: enabled, bridge: bridge);

/// Observes `NSWorkspace.isVoiceOverEnabled` for a macOS platform hint.
///
/// Unsupported platforms and a disabled gate return
/// [ScreenReaderObservation.unknown] without calling the bridge. Missing
/// symbols, failed calls and invalid bytes are also unknown. This state is
/// VoiceOver-specific and never establishes that a terminal is being read.
ScreenReaderObservation observeVoiceOver({
  required HintPlatform platform,
  bool enabled = macosVoiceOverHintEnabled,
  VoiceOverNativeBridge? bridge,
}) {
  if (!enabled || platform != HintPlatform.macos) {
    return ScreenReaderObservation.unknown;
  }
  final activeBridge = bridge ?? const FfiVoiceOverNativeBridge();
  Object? appKit;
  Object? runtime;
  Object? pool;
  var cleanupFailed = false;
  var result = ScreenReaderObservation.unknown;
  try {
    // AppKit registers NSWorkspace; libobjc supplies class, selector and pool
    // calls. Both handles must outlive every pointer obtained through them.
    appKit = activeBridge.open(_appKitPath);
    runtime = activeBridge.open(_objcPath);
    final workspaceClass = activeBridge.findClass(runtime, 'NSWorkspace');
    if (workspaceClass == nullptr) {
      result = ScreenReaderObservation.unknown;
    } else {
      final sharedSelector = activeBridge.registerSelector(
        runtime,
        'sharedWorkspace',
      );
      final enabledSelector = activeBridge.registerSelector(
        runtime,
        'isVoiceOverEnabled',
      );
      final respondsSelector = activeBridge.registerSelector(
        runtime,
        'respondsToSelector:',
      );
      if (sharedSelector == nullptr ||
          enabledSelector == nullptr ||
          respondsSelector == nullptr) {
        result = ScreenReaderObservation.unknown;
      } else {
        pool = activeBridge.pushAutoreleasePool(runtime);
        final workspace = activeBridge.sharedWorkspace(
          runtime,
          workspaceClass,
          sharedSelector,
        );
        if (workspace == nullptr) {
          result = ScreenReaderObservation.unknown;
        } else if (!activeBridge.respondsToSelector(
          runtime,
          workspace,
          respondsSelector,
          enabledSelector,
        )) {
          result = ScreenReaderObservation.unknown;
        } else {
          result = switch (activeBridge.readVoiceOverEnabled(
            runtime,
            workspace,
            enabledSelector,
          )) {
            0 => ScreenReaderObservation.negative,
            1 => ScreenReaderObservation.positive,
            _ => ScreenReaderObservation.unknown,
          };
        }
      }
    }
  } catch (_) {
    result = ScreenReaderObservation.unknown;
  } finally {
    if (pool != null) {
      try {
        activeBridge.popAutoreleasePool(runtime!, pool);
      } catch (_) {
        cleanupFailed = true;
      }
    }
    for (final handle in [runtime, appKit]) {
      if (handle == null) continue;
      try {
        activeBridge.close(handle);
      } catch (_) {
        cleanupFailed = true;
      }
    }
  }
  return cleanupFailed ? ScreenReaderObservation.unknown : result;
}
