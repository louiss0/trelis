// Temporary diagnosis for the macOS system numeric convention. The public
// system-default expectations report Unavailable there, so this probe reports
// which Foundation value the resolver cannot read. It is deleted once the
// resolver is repaired.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('macOS Foundation numeric convention fields', () {
    if (!Platform.isMacOS) return;
    final report = <String>[];
    void record(String text) {
      report.add(text);
      // stderr is unbuffered, so the fields read before a fatal Foundation
      // error remain visible in the job log.
      stderr.writeln('PROBE $text');
    }

    final probe = _Probe();
    final type = probe.classNamed('NSNumberFormatter');
    record('class=$type');
    if (type == nullptr) fail(report.join('\n'));
    final formatter = probe.send(probe.send(type, 'alloc'), 'init');
    record('formatter=$formatter');
    final locale = probe.send(probe.classNamed('NSLocale'), 'currentLocale');
    record('locale=${probe.string(locale, 'localeIdentifier')}');
    probe.send(formatter, 'setLocale:', locale);
    probe.sendInt(formatter, 'setNumberStyle:', 1);
    for (final name in [
      'decimalSeparator',
      'groupingSeparator',
      'minusSign',
      'negativeFormat',
      'negativePrefix',
      'negativeSuffix',
    ]) {
      record('$name=${probe.string(formatter, name)}');
    }
    for (final name in [
      'groupingSize',
      'secondaryGroupingSize',
      'usesGroupingSeparator',
    ]) {
      record('$name=${probe.integer(formatter, name)}');
    }
    probe.sendInt(formatter, 'setUsesGroupingSeparator:', 0);
    final number = probe.classNamed('NSNumber');
    final digits = StringBuffer();
    for (var i = 0; i < 10; i++) {
      final value = probe.sendInt(number, 'numberWithInt:', i);
      final text = probe.string(
        probe.send(formatter, 'stringFromNumber:', value),
        'description',
      );
      record('digit[$i]=$text');
      if (text != null && text.runes.length == 1) {
        digits.writeCharCode(text.runes.single);
      }
    }
    try {
      final convention = NumericConvention(
        decimalSeparator: probe.string(formatter, 'decimalSeparator')!,
        groupingSeparator: probe.string(formatter, 'groupingSeparator')!,
        grouping: [probe.integer(formatter, 'groupingSize')],
        nativeDigits: digits.toString(),
        negativeSign: probe.string(formatter, 'minusSign')!,
        negativePattern: NumericNegativePattern.leading,
      );
      record('convention=${convention.nativeDigits}');
    } catch (error) {
      record('convention-error=$error');
    }
    fail(report.join('\n'));
  });
}

final class _Probe {
  _Probe() : runtime = DynamicLibrary.open('/usr/lib/libobjc.A.dylib') {
    DynamicLibrary.open(
      '/System/Library/Frameworks/Foundation.framework/Foundation',
    );
  }
  final DynamicLibrary runtime;

  Pointer classNamed(String name) {
    final native = name.toNativeUtf8();
    try {
      return runtime.lookupFunction<
        Pointer Function(Pointer<Utf8>),
        Pointer Function(Pointer<Utf8>)
      >('objc_getClass')(native);
    } finally {
      calloc.free(native);
    }
  }

  Pointer selector(String name) {
    final native = name.toNativeUtf8();
    try {
      return runtime.lookupFunction<
        Pointer Function(Pointer<Utf8>),
        Pointer Function(Pointer<Utf8>)
      >('sel_registerName')(native);
    } finally {
      calloc.free(native);
    }
  }

  Pointer send(Pointer receiver, String name, [Pointer? argument]) {
    final select = selector(name);
    if (argument == null) {
      return runtime.lookupFunction<
        Pointer Function(Pointer, Pointer),
        Pointer Function(Pointer, Pointer)
      >('objc_msgSend')(receiver, select);
    }
    return runtime.lookupFunction<
      Pointer Function(Pointer, Pointer, Pointer),
      Pointer Function(Pointer, Pointer, Pointer)
    >('objc_msgSend')(receiver, select, argument);
  }

  Pointer sendInt(Pointer receiver, String name, int value) =>
      runtime.lookupFunction<
        Pointer Function(Pointer, Pointer, Int32),
        Pointer Function(Pointer, Pointer, int)
      >('objc_msgSend')(receiver, selector(name), value);

  int integer(Pointer receiver, String name) =>
      runtime.lookupFunction<
        IntPtr Function(Pointer, Pointer),
        int Function(Pointer, Pointer)
      >('objc_msgSend')(receiver, selector(name));

  String? string(Pointer receiver, String name) {
    final string = send(receiver, name);
    if (string == nullptr) return null;
    final characters = send(string, 'UTF8String');
    return characters == nullptr
        ? null
        : characters.cast<Utf8>().toDartString();
  }
}
