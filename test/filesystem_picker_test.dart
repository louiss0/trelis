import 'dart:io';

import 'package:prompty/prompty.dart';
import 'package:test/test.dart';

void main() {
  test('supplied file selection requires an existing file', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}literal\$name');
    await file.writeAsString('contents');
    final picker = FilePicker('File', base: dir.path);
    final result = await picker.prompt(source: SuppliedAnswer('literal\$name'));
    expect((result as Accepted<String>).value, file.path);
    expect(
      await picker.prompt(source: SuppliedAnswer('.')),
      isA<Unavailable<String>>(),
    );
    expect(await file.readAsString(), 'contents');
  });
  test('supplied directory selection requires an existing directory', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}file');
    await file.writeAsString('contents');
    final picker = DirectoryPicker('Directory', base: dir.path);
    expect(
      (await picker.prompt(
        source: SuppliedAnswer('.'),
      ) as Accepted<String>).value,
      '${dir.path}${Platform.pathSeparator}.',
    );
    expect(
      await picker.prompt(source: SuppliedAnswer('file')),
      isA<Unavailable<String>>(),
    );
  });
  test(
    'linear directory browser reviews and chooses its current directory',
    () async {
      final dir = await Directory.systemTemp.createTemp('picker_test');
      addTearDown(() => dir.delete(recursive: true));
      final out = StringBuffer();
      final result = await DirectoryPicker('Directory', base: dir.path).prompt(
        source: ScriptedInput(Stream.value('choose\r\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, dir.path);
      expect(out.toString(), contains('Current directory: ${dir.path}'));
      expect(out.toString(), contains('Choose'));
    },
  );
}
