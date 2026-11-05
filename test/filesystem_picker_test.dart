import 'dart:io';

import 'package:path/path.dart' as path;
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
  test('linear file browser chooses a listed file after review', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}${Platform.pathSeparator}answer.txt')
        .writeAsString('unchanged');
    await Directory('${dir.path}${Platform.pathSeparator}folder').create();
    final out = StringBuffer();
    final result = await FilePicker('File', base: dir.path).prompt(
      source: ScriptedInput(Stream.value('choose 1\r\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, file.path);
    expect(out.toString(), contains('1. answer.txt [file]'));
    expect(out.toString(), contains('2. folder [directory]'));
    expect(out.toString(), contains('Open'));
    expect(out.toString(), contains('Choose'));
    expect(await file.readAsString(), 'unchanged');
  });
  test(
    'rich file browser explicitly reveals and chooses hidden entries',
    () async {
      final dir = await Directory.systemTemp.createTemp('picker_test');
      addTearDown(() => dir.delete(recursive: true));
      final visible = await File('${dir.path}${Platform.pathSeparator}visible')
          .writeAsString('visible');
      final hidden = await File('${dir.path}${Platform.pathSeparator}.hidden')
          .writeAsString('hidden');
      final out = StringBuffer();
      final result = await FilePicker('File', base: dir.path).prompt(
        source: ScriptedInput(Stream.value('hidden\rchoose 1\r\r'), out),
        mode: PromptMode.rich,
      );
      expect((result as Accepted<String>).value, hidden.path);
      final transcript = out.toString();
      expect(
        transcript.indexOf('1. visible [file]'),
        lessThan(transcript.indexOf('Hidden entries: shown')),
      );
      expect(transcript, contains('2. visible [file]'));
      expect(transcript, contains('1. .hidden [file]'));
      expect(await visible.readAsString(), 'visible');
    },
  );
  test(
    'refresh replaces displayed references with a current listing',
    () async {
      final dir = await Directory.systemTemp.createTemp('picker_test');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}${Platform.pathSeparator}before')
          .writeAsString('a');
      final added = File('${dir.path}${Platform.pathSeparator}later');
      Stream<String> actions() async* {
        yield 'refresh\r';
        await added.writeAsString('b');
        yield 'refresh\rchoose 2\r\r';
      }

      final out = StringBuffer();
      final result = await FilePicker(
        'File',
        base: dir.path,
      ).prompt(source: ScriptedInput(actions(), out), mode: PromptMode.linear);
      expect((result as Accepted<String>).value, added.path);
      expect(out.toString(), contains('2. later [file]'));
    },
  );
  test('a stale listed reference cannot choose its replacement', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}${Platform.pathSeparator}entry')
        .writeAsString('original');
    var replaced = false;
    final out = _HookOutput((text) {
      if (!replaced && text.contains('1. entry [file]')) {
        replaced = true;
        file.deleteSync();
        file.writeAsStringSync('replacement');
      }
    });
    final result = await FilePicker('File', base: dir.path).prompt(
      source: ScriptedInput(Stream.value('choose 1\rchoose 1\r\r'), out),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, file.path);
    expect(out.toString(), contains('stale'));
    expect(await file.readAsString(), 'replacement');
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
  test(
    'linear directory browser accepts a literal path after review',
    () async {
      final dir = await Directory.systemTemp.createTemp('picker_test');
      addTearDown(() => dir.delete(recursive: true));
      final child = await Directory(
        '${dir.path}${Platform.pathSeparator}literal\$name',
      ).create();
      final out = StringBuffer();
      final result = await DirectoryPicker('Directory', base: dir.path).prompt(
        source: ScriptedInput(Stream.value('path\rliteral\$name\r\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, child.path);
      expect(out.toString(), contains('Choose ${child.path}'));
    },
  );
  test(
    'linear directory browser opens a listed directory before choosing it',
    () async {
      final dir = await Directory.systemTemp.createTemp('picker_test');
      addTearDown(() => dir.delete(recursive: true));
      final child = await Directory('${dir.path}${Platform.pathSeparator}child')
          .create();
      final out = StringBuffer();
      final result = await DirectoryPicker('Directory', base: dir.path).prompt(
        source: ScriptedInput(Stream.value('open 1\rchoose\r\r'), out),
        mode: PromptMode.linear,
      );
      expect((result as Accepted<String>).value, child.path);
      expect(out.toString(), contains('1. child'));
    },
  );
  test('linked directories require per-open opt-in', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final target = await Directory('${dir.path}${Platform.pathSeparator}target')
        .create();
    final browser = await Directory(
      '${dir.path}${Platform.pathSeparator}browser',
    ).create();
    final linked = '${browser.path}${Platform.pathSeparator}linked';
    await _directoryLink(linked, target.path);
    final out = StringBuffer();
    final result = await DirectoryPicker('Directory', base: browser.path)
        .prompt(
          source: ScriptedInput(
            Stream.value('open 1\ropen 1 links\rchoose\r\r'),
            out,
          ),
          mode: PromptMode.linear,
        );
    expect((result as Accepted<String>).value, linked);
    expect(out.toString(), contains('[link]'));
    expect(out.toString(), contains('explicit'));
    expect(out.toString(), contains('Linked traversal approved for this open'));
  });
  test('approved linked-directory cycles are rejected with context', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final linked = '${dir.path}${Platform.pathSeparator}loop';
    await _directoryLink(linked, dir.path);
    final out = StringBuffer();
    final result = await DirectoryPicker('Directory', base: dir.path).prompt(
      source: ScriptedInput(Stream.value('open 1 links\rchoose\r\r'), out),
      mode: PromptMode.rich,
    );
    expect((result as Accepted<String>).value, dir.path);
    expect(out.toString(), contains('cycle'));
    expect(out.toString(), contains(dir.path));
  });
  test('acceptance rechecks a selection removed during review', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}${Platform.pathSeparator}entry')
        .writeAsString('original');
    var removed = false;
    final out = _HookOutput((text) {
      if (!removed && text.contains('Choose ${file.path}.')) {
        removed = true;
        file.deleteSync();
      }
    });
    final result = await FilePicker('File', base: dir.path).prompt(
      source: ScriptedInput(Stream.value('choose 1\r\r'), out),
      mode: PromptMode.linear,
    );
    expect(result, isA<InputEnded<String>>());
    expect(out.toString(), contains('Target must exist'));
    expect(removed, isTrue);
  });
  test('parent navigation at a filesystem root remains at that root', () async {
    final root = path.rootPrefix(Directory.current.path);
    final result = await DirectoryPicker('Directory', base: root).prompt(
      source: ScriptedInput(Stream.value('parent\rchoose\r\r'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, root);
  });
  test('rich interaction requires a rich-capable source', () async {
    final result = await FilePicker('File').prompt(
      source: ScriptedInput(
        Stream.empty(),
        StringBuffer(),
        supportsRich: false,
      ),
      mode: PromptMode.rich,
    );
    expect(result, isA<Unavailable<String>>());
  });
  test('linear directory browser navigates to parent', () async {
    final dir = await Directory.systemTemp.createTemp('picker_test');
    addTearDown(() => dir.delete(recursive: true));
    final child = await Directory('${dir.path}${Platform.pathSeparator}child')
        .create();
    final result = await DirectoryPicker('Directory', base: child.path).prompt(
      source: ScriptedInput(Stream.value('parent\rchoose\r\r'), StringBuffer()),
      mode: PromptMode.linear,
    );
    expect((result as Accepted<String>).value, dir.path);
  });
}

Future<void> _directoryLink(String linked, String target) async {
  if (Platform.isWindows) {
    final result = await Process.run('cmd', [
      '/c',
      'mklink',
      '/J',
      linked,
      target,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Could not create junction: ${result.stderr}');
    }
  } else {
    await Link(linked).create(target);
  }
}

final class _HookOutput implements StringSink {
  _HookOutput(this.onWrite);
  final void Function(String) onWrite;
  final StringBuffer buffer = StringBuffer();

  @override
  void write(Object? object) {
    final text = '$object';
    buffer.write(text);
    onWrite(text);
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  String toString() => buffer.toString();
}
