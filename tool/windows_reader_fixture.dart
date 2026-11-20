import 'dart:ffi';
import 'dart:io';

import 'package:trelis/src/hint_observations.dart';
import 'package:trelis/src/windows_reader_hint.dart';

/// Reads the documented Windows screen-reader parameter once and reports the
/// outcome. The production gate stays off; this fixture opts in explicitly:
///
///     dart run tool/windows_reader_fixture.dart
///
/// A negative result does not prove that no screen reader is running, and
/// Narrator does not set this parameter. This is not reader qualification.
void main() {
  final binding = platformWindowsReaderBinding();
  final probe = WindowsReaderProbe(enabled: true, lookup: () => binding);
  final observation = probe(HintPlatform.windows);

  stdout.writeln('Platform      : ${Platform.operatingSystem}');
  stdout.writeln('OS            : ${Platform.environment['OS'] ?? '<unset>'}');
  stdout.writeln('Dart version  : ${Platform.version}');
  stdout.writeln('Dart ABI      : ${Abi.current()}');
  stdout.writeln(
    'Binding       : ${binding == null ? 'missing' : 'available'}',
  );
  stdout.writeln('Fixture gate  : enabled (production default: off)');
  stdout.writeln('Observation   : $observation');
}
