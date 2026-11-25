import 'dart:async';
import 'dart:io';

/// Shared support for the native TextInput fixture routes.
///
/// This library is test-only fixture infrastructure. It is not exported by
/// the package and must not become production API.
const nativeTriggerLimit = Duration(seconds: 60);

Future<bool> fileAppearedWithin(File trigger, Duration limit) async {
  final deadline = DateTime.now().add(limit);
  while (!trigger.existsSync()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

Future<bool> paintedTextWithin(
  NativeFixtureFailingStdout output,
  String text,
  Duration limit,
) async {
  final deadline = DateTime.now().add(limit);
  while (!output.text.contains(text)) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}

/// A selected output that can be armed to fail like a broken shared writer.
///
/// Only the members the native session path actually observes are real; the
/// rest of the standard output contract is unused here.
final class NativeFixtureFailingStdout implements Stdout {
  Object? failure;
  final StringBuffer _recording = StringBuffer();

  String get text => _recording.toString();

  @override
  bool get hasTerminal => false;

  @override
  bool get supportsAnsiEscapes => false;

  void _write(Object? value) {
    final armed = failure;
    if (armed != null) throw armed;
    _recording.write(value);
  }

  @override
  void write(Object? object) => _write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _write('$object\n');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
